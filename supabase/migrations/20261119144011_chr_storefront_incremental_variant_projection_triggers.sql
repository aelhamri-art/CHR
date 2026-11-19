-- CHR staging-scale ingestion: avoid O(variant_count²) catalog rebuilds
-- when a supplier uploads several SKU variants of one product.
create or replace function app_private.sync_variant_storefront_catalog()
returns trigger language plpgsql security definer set search_path=''
as $fn$
begin
 if tg_op<>'INSERT' then
  delete from public.storefront_catalog c
  where c.store_id=old.store_id and c.variant_id=old.id;
 end if;
 if tg_op<>'DELETE' then
  insert into public.storefront_catalog(
   store_id,product_id,variant_id,product_handle,title,description,vendor,category,
   variant_title,sku,price_minor,weight_grams,image_path,image_alt,updated_at)
  select v.store_id,p.id,v.id,p.handle,p.title,p.description,p.vendor,p.product_type,
   v.title,v.sku,v.price_minor,v.weight_grams,m.storage_path,m.alt_text,now()
  from public.product_variants v
  join public.products p on p.id=v.product_id and p.store_id=v.store_id and p.status='active'
  left join lateral (
   select pm.storage_path,pm.alt_text
   from public.product_media pm
   where pm.store_id=p.store_id and pm.product_id=p.id
   order by pm.position,pm.created_at limit 1
  ) m on true
  where v.store_id=new.store_id and v.id=new.id
  on conflict (store_id,variant_id) do update set
   product_id=excluded.product_id,product_handle=excluded.product_handle,
   title=excluded.title,description=excluded.description,vendor=excluded.vendor,
   category=excluded.category,variant_title=excluded.variant_title,sku=excluded.sku,
   price_minor=excluded.price_minor,weight_grams=excluded.weight_grams,
   image_path=excluded.image_path,image_alt=excluded.image_alt,updated_at=now();
 end if;
 return case when tg_op='DELETE' then old else new end;
end $fn$;
revoke all on function app_private.sync_variant_storefront_catalog() from public,anon,authenticated;
drop trigger if exists trg_variants_storefront on public.product_variants;
create trigger trg_variants_storefront after insert or update or delete on public.product_variants
for each row execute function app_private.sync_variant_storefront_catalog();
