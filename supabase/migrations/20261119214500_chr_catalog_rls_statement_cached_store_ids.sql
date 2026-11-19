-- CHR 100K / RLS performance: compute authorized store IDs once per statement,
-- rather than calling a SECURITY DEFINER lookup for every catalog variant row.
--
-- The definer function returns only store UUIDs based on auth.uid() and
-- immutable ownership / active membership; no user_metadata/JWT role is trusted.
-- DO NOT replace this function with client-supplied store claims.
create or replace function app_private.readable_store_ids()
returns uuid[] language sql stable security definer set search_path=''
as $$
 select coalesce(pg_catalog.array_agg(st.id),array[]::uuid[])
 from public.stores st
 where (select auth.uid()) is not null and (
  st.owner_user_id=(select auth.uid())
  or exists (
   select 1 from public.store_members m
   where m.store_id=st.id
     and m.user_id=(select auth.uid())
     and m.status='active'
  )
 )
$$;
revoke all on function app_private.readable_store_ids() from public,anon,authenticated;
grant execute on function app_private.readable_store_ids() to authenticated;

drop policy if exists storefront_catalog_authenticated on public.storefront_catalog;
create policy storefront_catalog_authenticated
 on public.storefront_catalog
 for select to authenticated
 using (
  store_id in (select pg_catalog.unnest(app_private.readable_store_ids()))
  or exists(
   select 1 from public.storefront_settings s
   where s.store_id=storefront_catalog.store_id and s.published
  )
 );
-- Keep the distinct anonymous policy unchanged: only published stores.
