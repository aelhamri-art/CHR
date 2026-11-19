-- Disposable CI PostgreSQL only, NOT Supabase production.
-- Two SKUs with one unit each, for concurrent overbooking and replay tests.
insert into public.customers(id,store_id,first_name,email)
values('f1000000-0000-4000-8000-000000000001',
'c3000000-0000-4000-8000-000000000003','Concurrency','test-only@invalid.example');
insert into public.locations(id,store_id,name)
values('f2000000-0000-4000-8000-000000000001',
'c3000000-0000-4000-8000-000000000003','Test-only concurrency warehouse');
insert into public.shipping_profiles(id,store_id,name)
values('f3000000-0000-4000-8000-000000000001',
'c3000000-0000-4000-8000-000000000003','Test-only concurrency shipping');
insert into public.shipping_zones(id,store_id,profile_id,name,countries)
values('f4000000-0000-4000-8000-000000000001',
'c3000000-0000-4000-8000-000000000003','f3000000-0000-4000-8000-000000000001',
'Test-only region',array['ZZ']);
insert into public.shipping_rates(store_id,zone_id,name,mode,amount_minor)
values('c3000000-0000-4000-8000-000000000003',
'f4000000-0000-4000-8000-000000000001','Test-only flat','flat',1000);
insert into public.tax_rules(store_id,country,name,rate_basis_points,tax_shipping,active)
values('c3000000-0000-4000-8000-000000000003','ZZ','Test-only VAT',2000,true,true);
insert into public.products(id,store_id,title,handle,status)
values
('f5000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000003','Race condition one','concurrency-one','active'),
('f5000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000003','Idempotent one','concurrency-idempotent','active');
insert into public.product_variants(id,store_id,product_id,title,sku,price_minor,weight_grams,taxable)
values
('f6000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000003','f5000000-0000-4000-8000-000000000001','Single stock','TEST-CONCURRENCY-1',10000,1000,true),
('f6000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000003','f5000000-0000-4000-8000-000000000002','Single stock','TEST-CONCURRENCY-2',10000,1000,true);
insert into public.inventory_levels(store_id,variant_id,location_id,on_hand,reserved)
values
('c3000000-0000-4000-8000-000000000003','f6000000-0000-4000-8000-000000000001','f2000000-0000-4000-8000-000000000001',1,0),
('c3000000-0000-4000-8000-000000000003','f6000000-0000-4000-8000-000000000002','f2000000-0000-4000-8000-000000000001',1,0);
select 'READY: two different single-stock SKUs for simultaneous order submissions' as status;
