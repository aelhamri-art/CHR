-- CHR P0 flexible workflow smoke test, in a transaction; nothing persists.
begin;
do $fixture$
declare s uuid; u uuid; c uuid; l uuid; sp uuid;z uuid;p uuid;v uuid;
begin
 s:='c3000000-0000-4000-8000-000000000003';
 u:='11000000-0000-4000-8000-000000000001';
 insert into auth.users(id,email) values(u,'owner-flex-test@invalid.example');
 insert into public.stores(id,owner_user_id,slug,name) values(s,u,'chr','CHR FLEXIBLE TEST');
 insert into public.customers(store_id,first_name,company,email)
 values(s,'Test','Société CHR','test@invalid.example') returning id into c;
 insert into public.locations(store_id,name) values(s,'Warehouse') returning id into l;
 insert into public.shipping_profiles(store_id,name) values(s,'Flexible delivery') returning id into sp;
 insert into public.shipping_zones(store_id,profile_id,name,countries)
 values(s,sp,'ZZ area',array['ZZ']) returning id into z;
 insert into public.shipping_rates(store_id,zone_id,name,mode,amount_minor)
 values(s,z,'Standard','flat',1000);
 insert into public.tax_rules(store_id,country,name,rate_basis_points,tax_shipping,active)
 values(s,'ZZ','Test tax 20%',2000,true,true);
 insert into public.products(store_id,title,handle,status)
 values(s,'Quote price product','quote-price-fixture','active') returning id into p;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams,taxable)
 values(s,p,'Standard','FLEXIBLE-QUOTE-ONE',10000,500,true) returning id into v;
 insert into public.inventory_levels(store_id,variant_id,location_id,on_hand,reserved)
 values(s,v,l,2,0);
 perform set_config('chr.test.flex',jsonb_build_object('store',s,'user',u,'customer',c,
   'location',l,'profile',sp,'variant',v)::text,true);
end $fixture$;
set local role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
do $business$
declare
 d jsonb:=current_setting('chr.test.flex')::jsonb;
 store uuid:=(d->>'store')::uuid; customer uuid:=(d->>'customer')::uuid;
 variant uuid:=(d->>'variant')::uuid; location uuid:=(d->>'location')::uuid;
 profile uuid:=(d->>'profile')::uuid;
 q jsonb; q2 jsonb; q3 jsonb; r jsonb; lines jsonb; key uuid:=gen_random_uuid();
 qid uuid; oid uuid; blocked boolean; cnt int; amount bigint;
begin
 -- Negotiated quote with backorder: 3 requested, 2 on hand, no stock reserved.
 lines:=jsonb_build_array(jsonb_build_object('variant_id',variant,'quantity',3,
      'unit_price_minor',8500,'price_reason','Remise professionnelle validée par le responsable'));
 q:=public.chr_save_sales_quote(store,lines,null,null,customer,'Client CHR',
    'contact@example.invalid','Première proposition',false,key);
 if q->>'status'<>'draft' or (q->>'revision')::int<>1
 or (q->>'subtotal_minor')::bigint<>25500 or (q->>'has_backorder')::boolean<>true then
  raise exception 'Invalid first quote %',q;end if;
 qid:=(q->>'quote_id')::uuid;
 select count(*) into cnt from public.inventory_levels where store_id=store and reserved<>0;
 if cnt<>0 then raise exception 'Quote incorrectly reserved physical stock';end if;
 r:=public.chr_save_sales_quote(store,lines,null,null,customer,'Client CHR',
    'contact@example.invalid','Première proposition',false,key);
 if r->>'status'<>'already_created' or (r->>'quote_id')::uuid<>qid
 then raise exception 'Idempotent quote replay failed';end if;
 r:=public.chr_set_sales_quote_status(store,qid,1,'proposed','Communication au client par téléphone');
 r:=public.chr_set_sales_quote_status(store,qid,1,'accepted','Accepté commercialement');
 blocked:=false;
 begin
  perform public.chr_save_sales_quote(store,lines,qid,1,customer,
     'Client CHR','contact@example.invalid','Modification surprise',false,null);
 exception when check_violation then blocked:=true;end;
 if not blocked then raise exception 'Accepted quote modified without explicit reopen';end if;
 lines:=jsonb_build_array(jsonb_build_object('variant_id',variant,'quantity',2,
      'unit_price_minor',9000,'price_reason','Tarif adapté au nouveau volume du client'));
 q2:=public.chr_save_sales_quote(store,lines,qid,1,customer,'Client CHR',
    'contact@example.invalid','Nouvelle version',true,null);
 if (q2->>'revision')::int<>2 or (q2->>'subtotal_minor')::bigint<>18000
 then raise exception 'Quote revision failed %',q2;end if;
 blocked:=false;
 begin
  perform public.chr_save_sales_quote(store,lines,qid,1,customer,
    'Client CHR','contact@example.invalid','Ancienne version',false,null);
 exception when serialization_failure then blocked:=true;end;
 if not blocked then raise exception 'Stale quote revision accepted';end if;
 select count(*) into cnt from public.chr_sales_quote_revisions
 where store_id=store and quote_id=qid;
 if cnt<>2 then raise exception 'Quote revision history missing';end if;
 select (line_snapshot->0->>'unit_price_minor')::bigint into amount
 from public.chr_sales_quote_revisions where store_id=store and quote_id=qid and revision=1;
 if amount<>8500 then raise exception 'Original commercial quote was rewritten';end if;
 -- Order at negotiated price: PostgreSQL computes shipping, tax, totals and stock.
 key:=gen_random_uuid();
 lines:=jsonb_build_array(jsonb_build_object('variant_id',variant,'quantity',1,
    'unit_price_minor',8500,'price_reason','Remise commerciale B2B validée'));
 r:=public.create_order(store,customer,location,profile,'ZZ','00000',lines,key);
 if (r->>'total_minor')::bigint<>11400 then
  raise exception 'Negotiated order total mismatch: %',r;end if;
 oid:=(r->>'order_id')::uuid;
 select unit_price_minor into amount from public.order_lines where store_id=store and order_id=oid;
 if amount<>8500 then raise exception 'Agreed unit price not saved';end if;
 select count(*) into cnt from public.chr_order_price_agreements
 where store_id=store and order_id=oid
   and base_unit_minor=10000 and agreed_unit_minor=8500;
 if cnt<>1 then raise exception 'Missing immutable negotiated price audit';end if;
 r:=public.create_order(store,customer,location,profile,'ZZ','00000',lines,key);
 if r->>'status'<>'already_created' then raise exception 'Order replay created duplicate';end if;
 -- Discount cap must be enforced on server, never by UI alone.
 blocked:=false;
 begin
  perform public.create_order(store,customer,location,profile,'ZZ','00000',
    jsonb_build_array(jsonb_build_object('variant_id',variant,'quantity',1,
      'unit_price_minor',1000,'price_reason','Unjustified discount above policy limit')),
    gen_random_uuid());
 exception when check_violation then blocked:=true;end;
 if not blocked then raise exception 'Price policy bypass accepted';end if;
end $business$;
rollback;
select 'PASS: flexible quotes, two immutable revisions, stock shortage visibility, negotiated order pricing, no duplicate orders' as result;