-- CHR production-readiness smoke checks: structural only, never impersonate real users.
do $verify$
declare n integer;
begin
 select count(*) into n from pg_tables where schemaname='public' and rowsecurity=true;
 if n<25 then raise exception 'Expected 25 public tables protected with RLS; found %',n;end if;
 if has_function_privilege('anon','public.create_order(uuid,uuid,uuid,uuid,text,text,jsonb,uuid)','EXECUTE')
 or has_function_privilege('anon','public.cancel_pending_order(uuid,uuid)','EXECUTE')
 or has_function_privilege('anon','public.confirm_manual_payment(uuid,uuid,text,text,text)','EXECUTE')
 or has_function_privilege('anon','public.fulfill_paid_order(uuid,uuid,text,text)','EXECUTE')
 or has_function_privilege('anon','public.import_products_batch(uuid,jsonb,uuid)','EXECUTE')
 then raise exception 'Anonymous business command executable';end if;
 if not exists(select 1 from pg_constraint where conname='stores_chr_eur_only')
 then raise exception 'Pilot currency constraint missing';end if;
 if not exists(select 1 from pg_policy where polname='customers_select')
 then raise exception 'Customer RLS policy missing';end if;
 if not exists(select 1 from storage.buckets where id='chr-product-media' and public=true)
 then raise exception 'Expected product media bucket';end if;
 if has_table_privilege('authenticated','public.orders','INSERT')
 or has_table_privilege('authenticated','public.inventory_levels','UPDATE')
 or has_table_privilege('authenticated','public.payment_transactions','INSERT')
 then raise exception 'Protected transaction table is directly writable';end if;
end $verify$;
select 'PASS: CHR structural security and transaction grants' as result;
