-- Production gate: zero overship, partial dispatch, duplicate replay, tenant isolation.
-- PostgreSQL 17 isolated CI ONLY; ROLLBACK always.
begin;
do $seed$
declare
 s uuid:='c3000000-0000-4000-8000-000000000003';
 owner uuid:='11000000-0000-4000-8000-000000000001';
 customer uuid;location uuid;profile uuid;zone uuid;product uuid;variant uuid;
begin
 insert into auth.users(id,email) values(owner,'shipment-owner@invalid.example'),
  ('22000000-0000-4000-8000-000000000002','shipment-attacker@invalid.example'),
  ('33000000-0000-4000-8000-000000000003','shipment-manager@invalid.example');
 insert into public.stores(id,owner_user_id,slug,name)
 values(s,owner,'chr','Shipment CI CHR');
 insert into public.store_members(store_id,user_id,role,status)
 values(s,'33000000-0000-4000-8000-000000000003','manager','active');
  insert into public.customers(store_id,first_name,company,email)
 values(s,'Delivery','CHR CI','shipment@invalid.example') returning id into customer;
 insert into public.locations(store_id,name) values(s,'Main warehouse') returning id into location;
 insert into public.shipping_profiles(store_id,name) values(s,'Delivery') returning id into profile;
 insert into public.shipping_zones(store_id,profile_id,name,countries)
 values(s,profile,'Test region',array['ZZ']) returning id into zone;
 insert into public.shipping_rates(store_id,zone_id,name,mode,amount_minor)
 values(s,zone,'Flat','flat',1000);
 insert into public.tax_rules(store_id,country,name,rate_basis_points,tax_shipping,active)
 values(s,'ZZ','VAT test',2000,true,true);
 insert into public.products(store_id,title,handle,status)
 values(s,'Shipment fixture','shipment-fixture','active') returning id into product;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams,taxable)
 values(s,product,'Standard','SHIPMENT-TEST-ONE',10000,1000,true)
 returning id into variant;
 insert into public.inventory_levels(store_id,variant_id,location_id,on_hand,reserved)
 values(s,variant,location,5,0);
 perform set_config('chr.test.ship',jsonb_build_object(
  'store',s,'customer',customer,'location',location,'profile',profile,'variant',variant)::text,true);
 perform set_config('request.jwt.claim.sub',owner::text,true);
end $seed$;
set local role authenticated;
do $test$
declare d jsonb:=current_setting('chr.test.ship')::jsonb;
 s uuid:=(d->>'store')::uuid;
 customer uuid:=(d->>'customer')::uuid;
 location uuid:=(d->>'location')::uuid;
 profile uuid:=(d->>'profile')::uuid;
 variant uuid:=(d->>'variant')::uuid;
 order_result jsonb;v_order_id uuid;line_id uuid;
 key uuid:=gen_random_uuid(); r jsonb;
 n int; physical int; reserved_count int;
 blocked boolean;ready jsonb;
begin
 order_result:=public.create_order(s,customer,location,profile,'ZZ','00000',
  jsonb_build_array(jsonb_build_object('variant_id',variant,'quantity',3)),gen_random_uuid());
 v_order_id:=(order_result->>'order_id')::uuid;
 select id into line_id from public.order_lines where store_id=s and order_id=v_order_id;
 if line_id is null then raise exception 'Cannot locate created order line';end if;
 perform public.confirm_manual_payment(s,v_order_id,'bank_transfer','BANK-TEST-12345','PAIEMENT RECU');

 r:=public.chr_dispatch_order_lines(s,v_order_id,
  jsonb_build_array(jsonb_build_object('order_line_id',line_id,'quantity',1)),
  'Local delivery','DELIVERY-REF-001',key);
 if r->>'fulfillment_status'<>'partial' then raise exception 'First dispatch not partial: %',r;end if;
 r:=public.chr_dispatch_order_lines(s,v_order_id,
  jsonb_build_array(jsonb_build_object('order_line_id',line_id,'quantity',1)),
  'Local delivery','DELIVERY-REF-001',key);
 if r->>'status'<>'already_dispatched' then raise exception 'Idempotent replay failed';end if;
 blocked:=false;
 begin
  perform public.chr_dispatch_order_lines(s,v_order_id,
   jsonb_build_array(jsonb_build_object('order_line_id',line_id,'quantity',2)),
   'Local delivery','DELIVERY-REF-001',key);
 exception when check_violation then blocked:=true;end;
 if not blocked then raise exception 'Same idempotency key accepted changed quantities';end if;
 select on_hand,reserved into physical,reserved_count
  from public.inventory_levels where store_id=s and variant_id=variant and location_id=location;
 if physical<>4 or reserved_count<>2 then
  raise exception 'Incorrect partial inventory: physical %, reserved %',physical,reserved_count;end if;

 blocked:=false;
 begin
  perform public.chr_dispatch_order_lines(s,v_order_id,
   jsonb_build_array(jsonb_build_object('order_line_id',line_id,'quantity',3)),
   'Local delivery','DELIVERY-REF-002',gen_random_uuid());
 exception when check_violation then blocked:=true;end;
 if not blocked then raise exception 'Overshipment was accepted';end if;

 r:=public.chr_dispatch_order_lines(s,v_order_id,
  jsonb_build_array(jsonb_build_object('order_line_id',line_id,'quantity',2)),
  'Local delivery','DELIVERY-REF-002',gen_random_uuid());
 if r->>'fulfillment_status'<>'fulfilled' then raise exception 'Final dispatch not completed: %',r;end if;
 select on_hand,reserved into physical,reserved_count from public.inventory_levels
  where store_id=s and variant_id=variant and location_id=location;
 if physical<>2 or reserved_count<>0 then raise exception 'Incorrect final inventory';end if;
 select count(*) into n from public.chr_shipments where store_id=s and order_id=v_order_id;
 if n<>2 then raise exception 'Incorrect shipment count';end if;
 select count(*) into n from public.inventory_movements where store_id=s and reason='fulfillment';
 if n<>2 then raise exception 'Double or missing movement';end if;
 select count(*) into n from public.orders
  where store_id=s and id=v_order_id and status='completed' and fulfillment_status='fulfilled';
 if n<>1 then raise exception 'Order status not complete';end if;

 ready:=public.chr_release_readiness(s);
 if (ready->>'checks_blocked')::integer<1
 or jsonb_array_length(ready->'checks')<10 then
  raise exception 'Release center silently passed incomplete shop';end if;
  -- A manager can handle business orders, but cannot certify bank receipt by default.
 perform set_config('request.jwt.claim.sub','33000000-0000-4000-8000-000000000003',true);
 blocked:=false;
 begin
  perform public.confirm_manual_payment(s,v_order_id,
   'bank_transfer','BANK-MANAGER-ATTEMPT','PAIEMENT RECU');
 exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'Manager bypassed financial approval policy';end if;
  perform set_config('request.jwt.claim.sub','22000000-0000-4000-8000-000000000002',true);
 select count(*) into n from public.chr_shipments where store_id=s;
 if n<>0 then raise exception 'Other tenant can read shipments';end if;
 blocked:=false;
 begin perform public.chr_release_readiness(s);
 exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'Other tenant can see production release status';end if;
 blocked:=false;
 begin
  perform public.chr_dispatch_order_lines(s,v_order_id,
   jsonb_build_array(jsonb_build_object('order_line_id',line_id,'quantity',1)),
   'Local delivery','ATTACK-9999',gen_random_uuid());
 exception when insufficient_privilege then blocked:=true;end;
 if not blocked then raise exception 'Other tenant bypassed shipment writer';end if;
end $test$;
rollback;
select 'PASS: partial and final dispatch; no overship; exactly-once; cross-tenant denied' as result;
