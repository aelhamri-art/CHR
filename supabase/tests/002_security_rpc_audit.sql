-- CHR permission smoke tests. Runs with elevated SQL inspection privileges; does not mutate data.
do $verify$
declare n int;
begin
 select count(*) into n
 from information_schema.triggers
 where event_object_schema='public'
 and trigger_name like 'trg_%_audit';
 if n < 9 then raise exception 'Expected >=9 audited CRUD tables, found %',n; end if;
 if has_function_privilege('anon','public.adjust_inventory(uuid,uuid,uuid,integer,text,uuid)','EXECUTE')
 then raise exception 'Anonymous can invoke inventory command'; end if;
 if not has_function_privilege('authenticated','public.adjust_inventory(uuid,uuid,uuid,integer,text,uuid)','EXECUTE')
 then raise exception 'Authenticated staff cannot call approved inventory command'; end if;
 if has_function_privilege('anon','public.eligible_shipping_rates(uuid,uuid,text,text,integer,bigint)','EXECUTE')
 then raise exception 'Anonymous can access rate engine'; end if;
 if not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='eligible_shipping_rates' and not p.prosecdef
 ) then raise exception 'Shipping quote function must be invoker'; end if;
 if not exists(
  select 1 from pg_constraint where conname='inventory_movements_tenant_level_fkey'
 ) then raise exception 'Missing compound FK for inventory audit'; end if;
end $verify$;
select 'PASS: trigger, execute-grant, and tenant constraint smoke tests' as verification;
