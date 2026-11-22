-- AXIUM OS CHR: accepted quote -> order, no re-entry and no double reservation.
-- Fully rolled back; isolated PostgreSQL 17 only.
begin;
do $seed$
declare s uuid:='c3000000-0000-4000-8000-000000000003';u uuid:='11000000-0000-4000-8000-000000000001';
 c uuid;l uuid;sp uuid;z uuid;p uuid;v uuid;
begin
 insert into auth.users(id,email) values(u,'quote2order@invalid.example');
 insert into public.stores(id,owner_user_id,slug,name) values(s,u,'chr','CONVERSION TEST');
 insert into public.customers(store_id,company,email) values(s,'CHR B2B','b2b@invalid.example') returning id into c;
 insert into public.locations(store_id,name) values(s,'Entrepôt test') returning id into l;
 insert into public.shipping_profiles(store_id,name) values(s,'Standard') returning id into sp;
 insert into public.shipping_zones(store_id,profile_id,name,countries)
 values(s,sp,'Europe test',array['ZZ']) returning id into z;
 insert into public.shipping_rates(store_id,zone_id,name,mode,amount_minor) values(s,z,'Forfait','flat',1000);
 insert into public.tax_rules(store_id,country,name,rate_basis_points,tax_shipping,active)
 values(s,'ZZ','TVA de test',2000,true,true);
 insert into public.products(store_id,title,handle,status)
 values(s,'Armoire froide test','armoire-test-quote-order','active') returning id into p;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams,taxable)
 values(s,p,'Standard','QUOTE-ORDER-TEST',10000,900,true) returning id into v;
 insert into public.inventory_levels(store_id,variant_id,location_id,on_hand,reserved)
 values(s,v,l,2,0);
 perform set_config('chr.test.conversion',jsonb_build_object('store',s,'customer',c,'location',l,'profile',sp,'variant',v)::text,true);
 perform set_config('request.jwt.claim.sub',u::text,true);
end $seed$;
set local role authenticated;
do $verify$
declare d jsonb:=current_setting('chr.test.conversion')::jsonb;
 s uuid:=(d->>'store')::uuid;c uuid:=(d->>'customer')::uuid;
 l uuid:=(d->>'location')::uuid;sp uuid:=(d->>'profile')::uuid;v uuid:=(d->>'variant')::uuid;
 quote jsonb;res jsonb;qid uuid;oid uuid;key uuid:=gen_random_uuid();n int;
begin
 quote:=public.chr_save_sales_quote(s,
  jsonb_build_array(jsonb_build_object('variant_id',v,'quantity',1,
   'unit_price_minor',8500,'price_reason','Prix commercial validé avec le client')),
  null,null,c,'Client CHR','client@invalid.example','Validation commerciale',false,gen_random_uuid());
 qid:=(quote->>'quote_id')::uuid;
 -- Cannot convert before customer approval.
 begin
  perform public.chr_convert_accepted_quote_to_order(s,qid,1,c,l,sp,'ZZ','00000',key);
  raise exception 'CRITICAL: draft quote converted without approval';
 exception when check_violation then null;end;
 perform public.chr_set_sales_quote_status(s,qid,1,'proposed','Proposition remise au client');
 perform public.chr_set_sales_quote_status(s,qid,1,'accepted','Accord du client confirmé par email');
 res:=public.chr_convert_accepted_quote_to_order(s,qid,1,c,l,sp,'ZZ','00000',key);
 if res->>'status'<>'converted' or (res->>'total_minor')::bigint<>11400 then
  raise exception 'Invalid quote conversion: %',res;end if;
 oid:=(res->>'order_id')::uuid;
 -- Different idempotency key still cannot create a second order for this quote.
 res:=public.chr_convert_accepted_quote_to_order(s,qid,1,c,l,sp,'ZZ','00000',gen_random_uuid());
 if res->>'status'<>'already_converted' or (res->>'order_id')::uuid<>oid then
  raise exception 'Same quote converted twice';end if;
 select count(*) into n from public.chr_quote_conversions where store_id=s and quote_id=qid;
 if n<>1 then raise exception 'Duplicate conversion link';end if;
 select count(*) into n from public.orders where store_id=s;
 if n<>1 then raise exception 'Duplicate orders created';end if;
 select sum(reserved) into n from public.inventory_levels where store_id=s;
 if n<>1 then raise exception 'Stock reservation corrupted';end if;
 select count(*) into n from public.chr_order_price_agreements
 where store_id=s and order_id=oid and agreed_unit_minor=8500 and base_unit_minor=10000;
 if n<>1 then raise exception 'Negotiated price not carried to order';end if;
 select count(*) into n from public.chr_sales_quote_events where quote_id=qid and event_type='converted';
 if n<>1 then raise exception 'Missing quote conversion event';end if;
end $verify$;
rollback;
select 'PASS: accepted quote converted once, original price honored, tax/shipping/stock correct, full audit' as result;