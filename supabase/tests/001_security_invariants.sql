-- Smoke tests for the CHR base schema. Run on a disposable test environment
-- or in a controlled verification session; no test data or persisted writes.
do $axium_test$
declare
 t text;
 tables text[] := array[
 'stores','store_members','products','product_variants','collections',
 'collection_products','locations','inventory_levels','inventory_movements',
 'customers','orders','order_lines','payment_transactions','refunds',
 'shipping_profiles','shipping_zones','shipping_rates','discounts',
 'audit_events','action_requests'
 ];
begin
 foreach t in array tables loop
  if not exists (
   select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relname=t and c.relkind='r' and c.relrowsecurity
  ) then
   raise exception 'RLS missing or table missing: %',t;
  end if;
  if has_table_privilege('anon',format('public.%I',t),'SELECT') then
   raise exception 'Anonymous SELECT grant found: %',t;
  end if;
 end loop;
 foreach t in array array['inventory_levels','inventory_movements','orders','order_lines','payment_transactions','refunds','audit_events','action_requests'] loop
  if has_table_privilege('authenticated',format('public.%I',t),'INSERT') or
     has_table_privilege('authenticated',format('public.%I',t),'UPDATE') or
     has_table_privilege('authenticated',format('public.%I',t),'DELETE') then
   raise exception 'Client write grant found on controlled business table: %',t;
  end if;
 end loop;
 if not exists (
  select 1 from pg_constraint c
  join pg_class t on t.oid=c.conrelid
  where t.relname='inventory_movements' and c.conname='inventory_movements_tenant_level_fkey'
 ) then
  raise exception 'Tenant-safe movement FK missing';
 end if;
end $axium_test$;
select 'PASS: 20 tables RLS, no anon read, protected transaction tables, tenant FK' as result;
