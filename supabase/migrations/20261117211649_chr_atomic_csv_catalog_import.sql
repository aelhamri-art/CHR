-- CHR catalogue CSV batch — one SQL transaction, idempotent and tenant-authorized.
create table if not exists public.catalog_import_requests(
 store_id uuid not null references public.stores(id),
 idempotency_key uuid not null,
 imported_count int not null check(imported_count>=0),
 created_at timestamptz not null default now(),
 primary key(store_id,idempotency_key)
);
alter table public.catalog_import_requests enable row level security;
revoke all on public.catalog_import_requests from anon,authenticated;

create or replace function public.import_products_batch(p_store_id uuid,p_rows jsonb,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
 v_item jsonb;
 v_handle text;
 v_title text;
 v_vendor text;
 v_sku text;
 v_variant_title text;
 v_status text;
 v_price bigint;
 v_weight int;
 v_product uuid;
 v_variant uuid;
 v_count int:=0;
 v_existing int;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id)
 then raise exception 'Access denied' using errcode='42501';end if;
 if p_store_id is null or p_idempotency_key is null or p_rows is null or
 jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows) not between 1 and 300 then
 raise exception 'CSV batch must contain 1 to 300 rows' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text||':'||p_idempotency_key::text,11));
 select imported_count into v_existing from public.catalog_import_requests
 where store_id=p_store_id and idempotency_key=p_idempotency_key;
 if found then return jsonb_build_object('status','already_imported','count',v_existing);end if;
 for v_item in select value from jsonb_array_elements(p_rows) loop
  if jsonb_typeof(v_item)<>'object' then raise exception 'Malformed CSV row' using errcode='22023';end if;
  v_handle:=lower(trim(coalesce(v_item->>'handle','')));
  v_title:=trim(coalesce(v_item->>'title',''));
  v_vendor:=nullif(trim(coalesce(v_item->>'vendor','')),'');
  v_sku:=trim(coalesce(v_item->>'sku',''));
  v_variant_title:=coalesce(nullif(trim(v_item->>'variant_title'),''),'Par défaut');
  v_status:=coalesce(nullif(trim(v_item->>'status'),''),'draft');
  if v_handle !~ '^[a-z0-9][a-z0-9-]{0,159}$' or length(v_title)<2 or length(v_title)>180
   or length(v_sku)<1 or length(v_sku)>100 or v_status not in ('draft','active','archived')
   or coalesce(v_item->>'price_minor','') !~ '^[0-9]{1,13}$'
   or coalesce(v_item->>'weight_grams','') !~ '^[0-9]{1,9}$'
  then raise exception 'Invalid CSV row: handle, title, SKU, status, price or weight' using errcode='22023';end if;
  v_price:=(v_item->>'price_minor')::bigint;
  v_weight:=(v_item->>'weight_grams')::int;
  insert into public.products(store_id,handle,title,vendor,status,created_by)
  values(p_store_id,v_handle,v_title,v_vendor,v_status,auth.uid())
  on conflict(store_id,handle) do update set title=excluded.title,vendor=excluded.vendor,status=excluded.status
  returning id into v_product;
  v_variant:=null;
  insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams,requires_shipping,taxable)
  values(p_store_id,v_product,v_variant_title,v_sku,v_price,v_weight,true,true)
  on conflict(store_id,sku) do update set
   title=excluded.title,price_minor=excluded.price_minor,weight_grams=excluded.weight_grams
   where public.product_variants.product_id=excluded.product_id
  returning id into v_variant;
  if v_variant is null then raise exception 'SKU % belongs to another product',v_sku using errcode='23505';end if;
  v_count:=v_count+1;
 end loop;
 insert into public.catalog_import_requests(store_id,idempotency_key,imported_count)
 values(p_store_id,p_idempotency_key,v_count);
 insert into public.audit_events(store_id,actor_id,actor_type,entity_type,action,after_state)
 values(p_store_id,auth.uid(),'human','products','batch_import',jsonb_build_object('count',v_count));
 return jsonb_build_object('status','imported','count',v_count);
end $$;
revoke all on function public.import_products_batch(uuid,jsonb,uuid) from public,anon;
grant execute on function public.import_products_batch(uuid,jsonb,uuid) to authenticated;
