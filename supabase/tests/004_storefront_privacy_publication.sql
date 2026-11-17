-- CHR storefront security/structure diagnostics; no persistent data writes.
do $test$
declare n int; blocked boolean:=false;
begin
 select count(*) into n from pg_tables
 where schemaname='public' and rowsecurity;
 if n < 32 then raise exception 'RLS is missing on storefront tables (% protected)',n;end if;
 if has_table_privilege('anon','public.storefront_customers','SELECT')
 or has_table_privilege('anon','public.storefront_addresses','SELECT')
 or has_table_privilege('anon','public.storefront_quotes','SELECT')
 or has_table_privilege('anon','public.storefront_saved_cart','SELECT')
 or has_table_privilege('anon','public.storefront_wishlist','SELECT') then
  raise exception 'Private customer data leaked to anon';end if;
 if not has_table_privilege('anon','public.storefront_catalog','SELECT') then
  raise exception 'Approved storefront catalog not readable';end if;
 if has_table_privilege('authenticated','public.storefront_catalog','INSERT') then
  raise exception 'Public catalog projection directly writable by browsers';end if;
 if has_function_privilege('anon','public.request_storefront_quote(uuid,jsonb,text,text,text,uuid)','EXECUTE')
 then raise exception 'Anonymous unthrottled quote RPC exposed';end if;
 if exists(select 1 from public.storefront_settings where public_slug='chr' and published)
 then raise exception 'Storefront chr must remain unpublished pending assets and terms';end if;
end $test$;
select 'PASS: private customer data denied, catalog projection read-only and publication held' as result;
