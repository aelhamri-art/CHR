-- CHR storefront: predictable policy plans and FK indexes.
create index if not exists idx_order_requests_order on public.order_requests(store_id,order_id);
create index if not exists idx_storefront_customers_uid on public.storefront_customers(user_id);
create index if not exists idx_storefront_quotes_uid on public.storefront_quotes(user_id);
create index if not exists idx_storefront_cart_variant on public.storefront_saved_cart(store_id,variant_id);
create index if not exists idx_storefront_wishlist_variant on public.storefront_wishlist(store_id,variant_id);

drop policy if exists storefront_settings_public_read on public.storefront_settings;
drop policy if exists storefront_settings_staff_read on public.storefront_settings;
create policy storefront_settings_anonymous on public.storefront_settings
for select to anon using(published);
create policy storefront_settings_authenticated on public.storefront_settings
for select to authenticated using(published or app_private.can_read_store(store_id));

drop policy if exists storefront_catalog_public_read on public.storefront_catalog;
drop policy if exists storefront_catalog_staff_preview on public.storefront_catalog;
create policy storefront_catalog_anonymous on public.storefront_catalog
for select to anon using(exists(select 1 from public.storefront_settings s where s.store_id=storefront_catalog.store_id and s.published));
create policy storefront_catalog_authenticated on public.storefront_catalog
for select to authenticated using(
 app_private.can_read_store(store_id) or
 exists(select 1 from public.storefront_settings s where s.store_id=storefront_catalog.store_id and s.published)
);
