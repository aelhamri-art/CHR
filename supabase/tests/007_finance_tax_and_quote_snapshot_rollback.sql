-- CHR: full transactional financial regression. Fixtures are always rolled back.
begin;
do $fixture$
declare s uuid;u uuid;c uuid;l uuid;pr uuid;z uuid;p1 uuid;p2 uuid;v1 uuid;v2 uuid;q uuid;
begin
 select id,owner_user_id into s,u from public.stores where slug='chr' limit 1;
 if s is null or u is null then raise exception 'Fixture owner not found';end if;
 insert into public.customers(store_id,first_name,email) values(s,'Rollback','finance@invalid.example') returning id into c;
 insert into public.locations(store_id,name) values(s,'Rollback financial location') returning id into l;
 insert into public.shipping_profiles(store_id,name) values(s,'Rollback financial profile') returning id into pr;
 insert into public.shipping_zones(store_id,profile_id,name,countries) values(s,pr,'Rollback ZZ',array['ZZ']) returning id into z;
 insert into public.shipping_rates(store_id,zone_id,name,mode,amount_minor) values(s,z,'Rollback flat','flat',1000);
 insert into public.tax_rules(store_id,country,name,rate_basis_points,tax_shipping,active) values(s,'ZZ','Rollback 20%',2000,true,true);
 insert into public.products(store_id,title,handle,status) values(s,'Rollback taxable','rollback-tax-'||substr(gen_random_uuid()::text,1,8),'active') returning id into p1;
 insert into public.products(store_id,title,handle,status) values(s,'Rollback exempt','rollback-exempt-'||substr(gen_random_uuid()::text,1,8),'active') returning id into p2;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams,taxable)
 values(s,p1,'Taxable','TAX-'||substr(gen_random_uuid()::text,1,8),10000,500,true) returning id into v1;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams,taxable)
 values(s,p2,'Exempt','EXE-'||substr(gen_random_uuid()::text,1,8),5000,500,false) returning id into v2;
 insert into public.inventory_levels(store_id,variant_id,location_id,on_hand) values(s,v1,l,10),(s,v2,l,10);
 insert into public.storefront_quotes(store_id,user_id,idempotency_key,contact_email,lines,estimate_minor)
 values(s,u,gen_random_uuid(),'test-only@invalid.example','[]'::jsonb,10000) returning id into q;
 perform set_config('chr.test.finance',jsonb_build_object('s',s,'c',c,'l',l,'pr',pr,'v1',v1,'v2',v2,'q',q)::text,true);
 perform set_config('request.jwt.claim.sub',u::text,true);
end $fixture$;
set local role authenticated;
do $verify$
declare d jsonb:=current_setting('chr.test.finance')::jsonb;
 res jsonb;oid uuid;order_tax bigint;lines_tax bigint;reserved_count integer;blocked boolean:=false;
begin
 res:=public.create_order((d->>'s')::uuid,(d->>'c')::uuid,(d->>'l')::uuid,(d->>'pr')::uuid,'ZZ','00000',
 jsonb_build_array(jsonb_build_object('variant_id',d->>'v2','quantity',1),
 jsonb_build_object('variant_id',d->>'v1','quantity',1)),gen_random_uuid());
 oid:=(res->>'order_id')::uuid;
 select o.tax_minor into order_tax from public.orders o where o.id=oid;
 select sum(ol.tax_minor) into lines_tax from public.order_lines ol where ol.order_id=oid;
 if order_tax<>2200 or lines_tax<>2000 then raise exception 'Tax mismatch (% / %)',order_tax,lines_tax;end if;
 select sum(i.reserved) into reserved_count from public.inventory_levels i where i.location_id=(d->>'l')::uuid
 and i.variant_id in ((d->>'v1')::uuid,(d->>'v2')::uuid);
 if reserved_count<>2 then raise exception 'Reserve mismatch';end if;
 perform public.cancel_pending_order((d->>'s')::uuid,oid);
 select sum(i.reserved) into reserved_count from public.inventory_levels i where i.location_id=(d->>'l')::uuid
 and i.variant_id in ((d->>'v1')::uuid,(d->>'v2')::uuid);
 if reserved_count<>0 then raise exception 'Cancel failed to release reservation';end if;
 update public.storefront_quotes set status='reviewing' where id=(d->>'q')::uuid;
 begin update public.storefront_quotes set estimate_minor=1 where id=(d->>'q')::uuid;
 exception when check_violation then blocked:=true;end;
 if not blocked then raise exception 'Quote amount tampering accepted';end if;
end $verify$;
rollback;
select 'PASS: line VAT, shipping VAT, reserve/cancel, immutable quote' as result;