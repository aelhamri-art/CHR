-- REAL two-tenant fixture RLS test, running against the actual CHR migrations.
-- Executed only in disposable PostgreSQL 17 GitHub Actions environment.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
do $tenant_a$
declare n bigint; r jsonb;
begin
 select count(*) into n from public.products
 where store_id='a1000000-0000-4000-8000-000000000001';
 if n<>10000 then raise exception 'Owner A cannot read own 10k parents: %',n;end if;
 select count(*) into n from public.products
 where store_id='b2000000-0000-4000-8000-000000000002';
 if n<>0 then raise exception 'P0: Owner A read tenant B products: %',n;end if;
 select count(*) into n from public.storefront_catalog
 where store_id='a1000000-0000-4000-8000-000000000001';
 if n<>100000 then raise exception 'Owner A cannot read 100k private SKUs: %',n;end if;
 select count(*) into n from public.storefront_catalog
 where store_id='b2000000-0000-4000-8000-000000000002';
 if n<>0 then raise exception 'P0: Owner A read tenant B catalog';end if;
 r:=public.chr_admin_catalog_page('b2000000-0000-4000-8000-000000000002','products','',null,null,50);
 if jsonb_array_length(r->'rows')<>0 then raise exception 'P0: admin RPC leaked tenant B products';end if;
 r:=public.chr_catalog_suggest('chr-scale-b','PRIVATE',5);
 if jsonb_array_length(r)<>0 then raise exception 'P0: suggest RPC leaked unpublished tenant B catalog';end if;
end $tenant_a$;

-- Distinct actual auth.users row, not just a random non-existent JWT.
select set_config('request.jwt.claim.sub','22000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"22000000-0000-4000-8000-000000000002","user_metadata":{"role":"superadmin","store_id":"a1000000-0000-4000-8000-000000000001"}}',true);
do $tenant_b$
declare n bigint; r jsonb; denied boolean:=false;
begin
 select count(*) into n from public.products where store_id='a1000000-0000-4000-8000-000000000001';
 if n<>0 then raise exception 'P0: Owner B read tenant A private products: %',n;end if;
 select count(*) into n from public.products where store_id='b2000000-0000-4000-8000-000000000002';
 if n<>50 then raise exception 'Owner B cannot read own products';end if;
 select count(*) into n from public.orders where store_id='a1000000-0000-4000-8000-000000000001';
 if n<>0 then raise exception 'P0: Owner B read A orders';end if;
 select count(*) into n from public.storefront_catalog where store_id='a1000000-0000-4000-8000-000000000001';
 if n<>0 then raise exception 'P0: Owner B sees A unpublished projection';end if;
 r:=public.chr_catalog_page('chr-scale-a','','','name',null,null,null,24);
 if jsonb_array_length(r->'items')<>0 then raise exception 'P0: public page RPC leaks A unpublished catalog';end if;
 update public.products set title='ATTACK CHR' where store_id='a1000000-0000-4000-8000-000000000001';
 get diagnostics n=row_count;
 if n<>0 then raise exception 'P0: Owner B modified tenant A products';end if;
 delete from public.products where store_id='a1000000-0000-4000-8000-000000000001';
 get diagnostics n=row_count;
 if n<>0 then raise exception 'P0: Owner B deleted tenant A products';end if;
 begin
  insert into public.products(store_id,title,handle,status) values
   ('a1000000-0000-4000-8000-000000000001','ATTACK','forbidden-staging','active');
 exception when insufficient_privilege then denied:=true;
 end;
 if not denied then raise exception 'P0: Owner B inserted product into A';end if;
 r:=public.chr_admin_catalog_page('a1000000-0000-4000-8000-000000000001','products','',null,null,50);
 if jsonb_array_length(r->'rows')<>0 then raise exception 'P0: Owner B can use A admin RPC';end if;
end $tenant_b$;

set local role anon;
do $anonymous$
declare n bigint;r jsonb;
begin
 select count(*) into n from public.storefront_settings;
 if n<>0 then raise exception 'P0: anon sees private settings';end if;
 select count(*) into n from public.storefront_catalog;
 if n<>0 then raise exception 'P0: anon sees unpublished SKUs';end if;
 r:=public.chr_catalog_page('chr-scale-a','','','name',null,null,null,24);
 if jsonb_array_length(r->'items')<>0 then raise exception 'P0: anonymous RPC bypassed publishing gate';end if;
end $anonymous$;
rollback;
select 'PASS: owner A, owner B and anon; 100k private rows, two real synthetic users and stores' as result;
