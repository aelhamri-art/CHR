CREATE OR REPLACE FUNCTION public.adjust_inventory(p_store_id uuid, p_variant_id uuid, p_location_id uuid, p_delta integer, p_reason text, p_idempotency_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_level_id uuid;
 v_previous integer;
 v_reserved integer;
 v_next integer;
 v_event uuid;
 v_existing uuid;
 v_existing_delta integer;
 v_existing_reason text;
 v_existing_variant uuid;
 v_existing_location uuid;
 v_existing_level uuid;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id) then
   raise exception 'Access denied' using errcode='42501';
 end if;
 if p_store_id is null or p_variant_id is null or p_location_id is null or p_idempotency_key is null
    or p_delta is null or p_delta = 0 or p_delta < -100000000 or p_delta > 100000000 then
    raise exception 'Invalid adjustment input' using errcode='22023';
 end if;
 if p_reason not in ('receipt','correction','damage','return','manual') then
    raise exception 'Unsupported adjustment reason' using errcode='22023';
 end if;
 -- Serialize all calls with the same tenant + idempotency key, regardless of SKU.
 perform pg_catalog.pg_advisory_xact_lock(
  pg_catalog.hashtextextended('chr:inventory:'||p_store_id::text||':'||p_idempotency_key::text,17));
 select m.id,m.delta,m.reason,l.variant_id,l.location_id,l.id
 into v_existing,v_existing_delta,v_existing_reason,v_existing_variant,v_existing_location,v_existing_level
 from public.inventory_movements m
 join public.inventory_levels l on l.store_id=m.store_id and l.id=m.inventory_level_id
 where m.store_id=p_store_id and m.idempotency_key=p_idempotency_key;
 if found then
  if v_existing_variant<>p_variant_id or v_existing_location<>p_location_id
    or v_existing_delta<>p_delta or v_existing_reason<>p_reason then
    raise exception 'Idempotency key reused with a different inventory payload' using errcode='23514';
  end if;
  return (select jsonb_build_object('status','already_applied','movement_id',v_existing,
    'on_hand',i.on_hand,'reserved',i.reserved)
    from public.inventory_levels i where i.id=v_existing_level and i.store_id=p_store_id);
 end if;
 if not exists(select 1 from public.product_variants where store_id=p_store_id and id=p_variant_id)
    or not exists(select 1 from public.locations where store_id=p_store_id and id=p_location_id and active=true) then
    raise exception 'Variant or active location not found in store' using errcode='23503';
 end if;
 insert into public.inventory_levels (store_id, variant_id, location_id,on_hand,reserved)
 values (p_store_id,p_variant_id,p_location_id,0,0)
 on conflict (store_id,variant_id,location_id) do nothing;

 select id,on_hand,reserved into v_level_id,v_previous,v_reserved
 from public.inventory_levels where store_id=p_store_id and variant_id=p_variant_id and location_id=p_location_id
 for update;

 -- The idempotency advisory lock above precedes this row lock; no duplicate adjustment can slip through.
 v_next := v_previous + p_delta;
 if v_next < v_reserved or v_next < 0 then
   raise exception 'Insufficient available inventory' using errcode='23514';
 end if;
 update public.inventory_levels set on_hand=v_next,updated_at=now() where id=v_level_id;
 insert into public.inventory_movements(store_id,inventory_level_id,delta,reason,actor_user_id,idempotency_key)
 values(p_store_id,v_level_id,p_delta,p_reason,auth.uid(),p_idempotency_key)
 returning id into v_event;
 insert into public.audit_events(store_id,actor_id,actor_type,entity_type,entity_id,action,before_state,after_state)
 values(p_store_id,auth.uid(),'human','inventory_levels',v_level_id,'adjust',
 jsonb_build_object('on_hand',v_previous),jsonb_build_object('on_hand',v_next,'delta',p_delta,'reason',p_reason));
 return jsonb_build_object('status','applied','movement_id',v_event,'on_hand',v_next,'reserved',v_reserved);
end; $function$
;