-- CHR proof-of-behavior: all writes are rolled back. Run against staging or a disposable DB.
-- This is a pagination correctness test, NOT a 100,000-row performance benchmark.
begin;
do $$
declare
 v_store uuid;
 v_pid uuid;
 v_first jsonb;
 v_second jsonb;
 v_third jsonb;
 v_ids uuid[];
 v_i integer;
begin
 select id into v_store from public.stores where slug='chr' limit 1;
 if v_store is null then raise exception 'Fixture store chr missing';end if;
 for v_i in 1..55 loop
  insert into public.products(store_id,title,handle,status)
  values(v_store,'Scale fixture '||lpad(v_i::text,4,'0'),
    'scale-fixture-'||substr(replace(gen_random_uuid()::text,'-',''),1,20),'active')
  returning id into v_pid;
  insert into public.product_variants(store_id,product_id,title,sku,price_minor,weight_grams)
  values(v_store,v_pid,'Standard','SCALE-'||substr(replace(gen_random_uuid()::text,'-',''),1,14),
    v_i*100,100);
 end loop;
 v_first:=public.chr_catalog_page('chr','Scale fixture',null,'name',null,null,null,24);
 if jsonb_array_length(v_first->'items') <> 24 or (v_first->>'has_more')::boolean is not true
 then raise exception 'First catalog page failed';end if;
 v_second:=public.chr_catalog_page('chr','Scale fixture',null,'name',
   v_first->'next_cursor'->>'title',
   (v_first->'next_cursor'->>'price')::bigint,
   (v_first->'next_cursor'->>'id')::uuid,24);
 if jsonb_array_length(v_second->'items') <> 24 or (v_second->>'has_more')::boolean is not true
 then raise exception 'Second catalog page failed';end if;
 v_third:=public.chr_catalog_page('chr','Scale fixture',null,'name',
   v_second->'next_cursor'->>'title',
   (v_second->'next_cursor'->>'price')::bigint,
   (v_second->'next_cursor'->>'id')::uuid,24);
 if jsonb_array_length(v_third->'items') <> 7 or (v_third->>'has_more')::boolean is not false
 then raise exception 'Third catalog page failed';end if;
 select array_agg(distinct (a.value->>'variant_id')::uuid) into v_ids
 from jsonb_array_elements(
  (v_first->'items')||(v_second->'items')||(v_third->'items')) as a(value);
 if cardinality(v_ids) <> 55 then raise exception 'Cursor duplicated/skipped variants';end if;
 if jsonb_array_length(public.chr_catalog_suggest('chr','Scale fixture',5))<>5
 then raise exception 'Suggestion limit not enforced';end if;
end $$;
rollback;

-- Anonymous users must not see the unpublished storefront, including via SECURITY INVOKER RPC.
begin;
set local role anon;
do $$
begin
 if jsonb_array_length((public.chr_catalog_page('chr','',null,'name',null,null,null,24))->'items')>0
 then raise exception 'Private catalog visible anonymously';end if;
 if jsonb_array_length(public.chr_catalog_suggest('chr','four',5))>0
 then raise exception 'Private search visible anonymously';end if;
end $$;
rollback;

select 'PASS: 55 rolled-back records, three seek pages, no gaps/duplicates, anonymous isolation' as result;
