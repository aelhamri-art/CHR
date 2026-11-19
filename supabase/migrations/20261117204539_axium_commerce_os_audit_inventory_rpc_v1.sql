-- CHR : audited mutations for editable configuration and atomic stock changes.
-- Committed as a separate migration and designed for authenticated API calls only.
-- Never trust a client-supplied actor or store membership.
create or replace function app_private.audit_mutation() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  oldj jsonb;
  newj jsonb;
  st uuid;
  rowid uuid;
begin
  oldj := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end;
  newj := case when tg_op in ('UPDATE','INSERT') then to_jsonb(new) else null end;
  st := coalesce((newj->>'store_id')::uuid,(oldj->>'store_id')::uuid);
  rowid := coalesce((newj->>'id')::uuid,(oldj->>'id')::uuid);
  -- Do not persist customer PII or profile addresses in immutable audit events.
  if tg_table_name in ('customers','locations') then
    oldj := case when oldj is null then null else jsonb_build_object('id',oldj->'id','redacted',true) end;
    newj := case when newj is null then null else jsonb_build_object('id',newj->'id','redacted',true) end;
  end if;
  insert into public.audit_events (store_id,actor_id,actor_type,entity_type,entity_id,action,before_state,after_state)
  values (st,(select auth.uid()),'human',tg_table_name,rowid,lower(tg_op),oldj,newj);
  return case when tg_op='DELETE' then old else new end;
end; $$;
revoke all on function app_private.audit_mutation() from public;
do $$
declare t text;
begin
  foreach t in array array['products','product_variants','collections','locations','customers','shipping_profiles','shipping_zones','shipping_rates','discounts']
  loop
    execute format('create trigger trg_%I_audit after insert or update or delete on public.%I for each row execute function app_private.audit_mutation()',t,t);
  end loop;
end $$;

alter table public.inventory_movements
 add column idempotency_key uuid;
create unique index idx_inventory_movements_idempotency on public.inventory_movements(store_id,idempotency_key) where idempotency_key is not null;

create or replace function public.adjust_inventory(
  p_store_id uuid, p_variant_id uuid, p_location_id uuid,
  p_delta integer, p_reason text, p_idempotency_key uuid
) returns jsonb
language plpgsql security definer
set search_path=''
as $$
declare
 v_level_id uuid;
 v_previous integer;
 v_reserved integer;
 v_next integer;
 v_event uuid;
 v_existing uuid;
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

 -- The lock on this inventory level makes repeated operations serial at this SKU/location.
 select id into v_existing from public.inventory_movements
 where store_id=p_store_id and idempotency_key=p_idempotency_key;
 if found then
   return jsonb_build_object('status','already_applied','movement_id',v_existing,'on_hand',v_previous,'reserved',v_reserved);
 end if;
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
end; $$;
revoke all on function public.adjust_inventory(uuid,uuid,uuid,integer,text,uuid) from public, anon;
grant execute on function public.adjust_inventory(uuid,uuid,uuid,integer,text,uuid) to authenticated;
