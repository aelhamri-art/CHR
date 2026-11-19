-- CHR projection consistency: variant insert/update/delete and product reclassification.
-- Complete fixture and trigger effects are rolled back.
begin;
do $test$
declare s uuid;p uuid;v1 uuid;v2 uuid;n integer;c text;pr bigint;
begin
 select id into s from public.stores where slug='chr';
 if s is null then raise exception 'Fixture store missing';end if;
 insert into public.products(store_id,title,handle,status,product_type)
 values(s,'Rollback oven','rollback-projection-'||substr(gen_random_uuid()::text,1,8),'active','Fours') returning id into p;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor)
 values(s,p,'Version A','R-A-'||substr(gen_random_uuid()::text,1,8),15000) returning id into v1;
 insert into public.product_variants(store_id,product_id,title,sku,price_minor)
 values(s,p,'Version B','R-B-'||substr(gen_random_uuid()::text,1,8),25000) returning id into v2;
 select count(*) into n from public.storefront_catalog where product_id=p;
 if n<>2 then raise exception 'Projection insertion missing variant (%).',n;end if;
 update public.product_variants set price_minor=19500 where id=v1;
 select price_minor into pr from public.storefront_catalog where variant_id=v1;
 if pr<>19500 then raise exception 'Variant price update not reflected';end if;
 update public.products set title='Rollback oven renamed',product_type='Cuisson' where id=p;
 select count(*) into n from public.storefront_catalog where product_id=p and title='Rollback oven renamed' and category='Cuisson';
 if n<>2 then raise exception 'Product update did not propagate to variants';end if;
 delete from public.product_variants where id=v2;
 select count(*) into n from public.storefront_catalog where product_id=p;
 if n<>1 then raise exception 'Deleted variant remains visible';end if;
 update public.products set status='archived' where id=p;
 select count(*) into n from public.storefront_catalog where product_id=p;
 if n<>0 then raise exception 'Archived product remains visible';end if;
end $test$;
rollback;
select 'PASS: insert/update/delete/reclassify/archive, no persisted fixtures' as result;