CREATE OR REPLACE FUNCTION public.request_storefront_quote(p_store_id uuid, p_lines jsonb, p_company text, p_email text, p_notes text, p_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_id uuid;v_item jsonb;v_qty int;v_id_variant uuid;v_product record;
 v_snapshot jsonb:='[]'::jsonb;v_total bigint:=0;v_seen uuid[]:=array[]::uuid[];
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 if not exists(select 1 from public.storefront_settings where store_id=p_store_id and published=true)
 then raise exception 'Store not published' using errcode='23514';end if;
 if not exists(select 1 from public.storefront_customers where store_id=p_store_id and user_id=auth.uid())
 then raise exception 'Customer profile required' using errcode='42501';end if;
 if p_key is null or p_lines is null or jsonb_typeof(p_lines)<>'array'
 or jsonb_array_length(p_lines) not between 1 and 25
 or length(trim(coalesce(p_email,'')))<5 or position('@' in p_email)=0
 or length(coalesce(p_notes,''))>3000 or length(trim(coalesce(p_email,'')))>254
 or length(coalesce(p_company,''))>180 then raise exception 'Invalid quote request' using errcode='22023';end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('chr:quote:'||p_store_id::text||':'||auth.uid()::text,17));
 select id into v_id from public.storefront_quotes where store_id=p_store_id and user_id=auth.uid() and idempotency_key=p_key;
 if found then return jsonb_build_object('quote_id',v_id,'status','already_created');end if;
 if (select count(*) from public.storefront_quotes where user_id=auth.uid() and store_id=p_store_id and created_at>now()-interval '1 day')>=10
 then raise exception 'Too many quote requests today' using errcode='22023';end if;
 for v_item in select value from jsonb_array_elements(p_lines) loop
  if jsonb_typeof(v_item)<>'object'
  or coalesce(v_item->>'variant_id','') !~ '^[0-9a-fA-F-]{36}$'
  or coalesce(v_item->>'quantity','') !~ '^[0-9]+$' then
   raise exception 'Invalid quote line' using errcode='22023';end if;
  v_id_variant:=(v_item->>'variant_id')::uuid;
  v_qty:=(v_item->>'quantity')::int;
  if v_qty<1 or v_qty>999 or v_id_variant=any(v_seen) then raise exception 'Invalid or duplicate quote variant' using errcode='22023';end if;
  v_seen:=pg_catalog.array_append(v_seen,v_id_variant);
  select title,variant_title,price_minor,sku into v_product
  from public.storefront_catalog where store_id=p_store_id and variant_id=v_id_variant;
  if not found then raise exception 'Unpublished item in quote' using errcode='23514';end if;
  v_total:=v_total + (v_product.price_minor*v_qty);
  v_snapshot:=v_snapshot||jsonb_build_array(jsonb_build_object(
   'variant_id',v_id_variant,'title',v_product.title,'variant_title',v_product.variant_title,
   'sku',v_product.sku,'quantity',v_qty,'unit_price_minor',v_product.price_minor));
 end loop;
 insert into public.storefront_quotes(store_id,user_id,idempotency_key,company_name,contact_email,notes,lines,estimate_minor)
 values(p_store_id,auth.uid(),p_key,left(trim(coalesce(p_company,'')),180),left(trim(p_email),254),
 p_notes,v_snapshot,v_total) returning id into v_id;
 return jsonb_build_object('quote_id',v_id,'status','created','estimate_minor',v_total);
end $function$
;

-- Status changes only: preserve original customer intent and priced snapshot.
create or replace function app_private.protect_quote_snapshot()
returns trigger language plpgsql set search_path=''
as $guard$
begin
 if new.id is distinct from old.id
 or new.store_id is distinct from old.store_id
 or new.user_id is distinct from old.user_id
 or new.idempotency_key is distinct from old.idempotency_key
 or new.company_name is distinct from old.company_name
 or new.contact_email is distinct from old.contact_email
 or new.notes is distinct from old.notes
 or new.lines is distinct from old.lines
 or new.estimate_minor is distinct from old.estimate_minor
 or new.created_at is distinct from old.created_at then
  raise exception 'Quote snapshot immutable; status-only updates allowed' using errcode='23514';
 end if;
 return new;
end $guard$;
revoke all on function app_private.protect_quote_snapshot() from public,anon,authenticated;
drop trigger if exists trg_quote_snapshot_immutable on public.storefront_quotes;
create trigger trg_quote_snapshot_immutable before update on public.storefront_quotes
for each row execute function app_private.protect_quote_snapshot();
