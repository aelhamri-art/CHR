-- CHR import regression: ten SKUs share one parent; identical retry avoids rewrites.
-- Simulated owner session and ALL fixtures rolled back.
begin;
do $fixture$
declare s uuid;u uuid;h text;arr jsonb:='[]'::jsonb;i int;
begin
 select id,owner_user_id into s,u from public.stores where slug='chr';
 h:='rollback-batch-'||substr(gen_random_uuid()::text,1,8);
 for i in 1..10 loop
  arr:=arr||jsonb_build_array(jsonb_build_object(
   'handle',h,'title','Batch invariant fixture','vendor','Test CHR',
   'category','Cuisson','status','active','sku',h||'-'||i,
   'variant_title','Version '||i,'price_minor',10000+i,'weight_grams',1000+i));
 end loop;
 perform set_config('chr.test.import',jsonb_build_object('store',s,'handle',h,'rows',arr)::text,true);
 perform set_config('request.jwt.claim.sub',u::text,true);
end $fixture$;
set local role authenticated;
do $verify$
declare d jsonb:=current_setting('chr.test.import')::jsonb;r jsonb;pid uuid;before_ctid text;after_ctid text;
 before_variants text[];after_variants text[];n int;rows jsonb;price bigint;
begin
 rows:=d->'rows';
 r:=public.import_products_batch((d->>'store')::uuid,rows,gen_random_uuid());
 if r->>'status'<>'imported' or (r->>'count')::int<>10 then raise exception 'Initial batch failed';end if;
 select id,ctid::text into pid,before_ctid from public.products
  where store_id=(d->>'store')::uuid and handle=d->>'handle';
 select array_agg(ctid::text order by sku) into before_variants
  from public.product_variants where product_id=pid;
 if cardinality(before_variants)<>10 then raise exception 'Expected 10 variants';end if;
 select count(*) into n from public.storefront_catalog where product_id=pid and category='Cuisson';
 if n<>10 then raise exception 'Projection did not retain 10 category variants';end if;
 r:=public.import_products_batch((d->>'store')::uuid,rows,gen_random_uuid());
 if r->>'status'<>'imported' then raise exception 'Identical import retry failed';end if;
 select ctid::text into after_ctid from public.products where id=pid;
 select array_agg(ctid::text order by sku) into after_variants from public.product_variants where product_id=pid;
 if before_ctid<>after_ctid or before_variants<>after_variants then
  raise exception 'Duplicate file rewrote unchanged parent or variants';end if;
 rows:=jsonb_set(rows,'{0,price_minor}','99999'::jsonb);
 r:=public.import_products_batch((d->>'store')::uuid,rows,gen_random_uuid());
 select price_minor into price from public.storefront_catalog
  where product_id=pid and sku=(d->>'handle')||'-1';
 if price<>99999 then raise exception 'Updated SKU price not refreshed';end if;
 select ctid::text into after_ctid from public.products where id=pid;
 if before_ctid<>after_ctid then raise exception 'Variant-only price update rewrote parent';end if;
end $verify$;
rollback;
select 'PASS: ten SKUs one parent, duplicate no-op, changed SKU projection, rollback' as result;