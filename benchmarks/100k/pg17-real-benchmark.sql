-- CHR: REAL 100,000-SKU cursor walk and server-side latency sample.
-- Must run on disposable PostgreSQL 17 Actions service with full CHR migrations.
set statement_timeout='12min';
set role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',false);

create temp table chr_seen_variants(id uuid primary key);
create temp table chr_bench_samples(
 operation text not null,
 latency_ms numeric not null,
 returned_rows integer not null
);
do $walk$
declare
 v_cursor jsonb:=null; v_page jsonb; v_next jsonb; v_items jsonb;
 v_i integer:=0;v_count integer:=0;v_more boolean:=true;
begin
 while v_more loop
  v_page:=public.chr_catalog_page('chr-scale-a','',null,'name',
   v_cursor->>'title',(v_cursor->>'price')::bigint,(v_cursor->>'id')::uuid,48);
  v_items:=v_page->'items';
  v_count:=jsonb_array_length(v_items);
  if v_count<1 or v_count>48 then raise exception 'Invalid cursor page count %',v_count;end if;
  insert into chr_seen_variants(id)
   select (j.value->>'variant_id')::uuid from jsonb_array_elements(v_items) j(value);
  v_i:=v_i+1;
  if v_i>2500 then raise exception 'Cursor did not terminate after 2500 pages';end if;
  v_more:=(v_page->>'has_more')::boolean;
  v_next:=v_page->'next_cursor';
  if v_more and v_next is null then raise exception 'Missing next cursor';end if;
  v_cursor:=v_next;
 end loop;
 if v_i<>2084 then raise exception 'Expected 2084 pages at size 48, got %',v_i;end if;
 if (select count(*) from chr_seen_variants)<>100000 then
  raise exception 'Expected exactly 100000 unique SKUs, got %',
   (select count(*) from chr_seen_variants);
 end if;
 raise notice 'FULL CURSOR WALK PASSED: 100000 unique SKU, 2084 pages, zero duplicates';
end $walk$;

-- Latencies reflect PostgreSQL stored-functions, excluding HTTP/network/browser.
do $bench$
declare
 t0 timestamptz;v jsonb;i integer;query text;row_count int;
begin
 for i in 1..250 loop
  query:=case i%5 when 0 then 'Four' when 1 then 'Armoire'
   when 2 then 'Table inox' when 3 then 'Hotte'
   else 'CHR-STAGING-chr-stg-a-00001-01' end;
  t0:=clock_timestamp();
  v:=public.chr_catalog_page('chr-scale-a',query,null,
   case when i%3=0 then 'price-high' when i%3=1 then 'name' else 'price-low' end,
   null,null,null,24);
  row_count:=jsonb_array_length(v->'items');
  insert into chr_bench_samples values('catalog_page',
   extract(epoch from clock_timestamp()-t0)*1000,row_count);
 end loop;
 for i in 1..250 loop
  query:=case i%5 when 0 then 'Four' when 1 then 'Armoire'
   when 2 then 'inox' when 3 then 'Friteuse' else 'CHR-STAGING-chr-stg-a-00001' end;
  t0:=clock_timestamp();
  v:=public.chr_catalog_suggest('chr-scale-a',query,5);
  row_count:=jsonb_array_length(v);
  insert into chr_bench_samples values('catalog_suggest',
   extract(epoch from clock_timestamp()-t0)*1000,row_count);
 end loop;
 for i in 1..100 loop
  query:='chr-stg-a-'||lpad((1+(i*97)%10000)::text,5,'0');
  t0:=clock_timestamp();
  v:=public.chr_catalog_product('chr-scale-a',query);
  row_count:=jsonb_array_length(v);
  insert into chr_bench_samples values('product_detail',
   extract(epoch from clock_timestamp()-t0)*1000,row_count);
 end loop;
end $bench$;
select operation,count(*) as samples,
 round(min(latency_ms),2) as min_ms,
 round((percentile_cont(0.5) within group (order by latency_ms))::numeric,2) as p50_ms,
 round((percentile_cont(0.95) within group (order by latency_ms))::numeric,2) as p95_ms,
 round((percentile_cont(0.99) within group (order by latency_ms))::numeric,2) as p99_ms,
 round(max(latency_ms),2) as max_ms,
 min(returned_rows) as min_rows,max(returned_rows) as max_rows
from chr_bench_samples group by operation order by operation;

-- Data file for independent inspection; no secrets or PII.
\copy (select operation,latency_ms,returned_rows from chr_bench_samples order by operation,latency_ms) to 'artifacts/chr-100k-db-latencies.csv' with (format csv,header true);
\copy (select operation,count(*) as samples,round((percentile_cont(0.95) within group (order by latency_ms))::numeric,2) as p95_ms,round((percentile_cont(0.99) within group (order by latency_ms))::numeric,2) as p99_ms from chr_bench_samples group by operation order by operation) to 'artifacts/chr-100k-p95-p99.csv' with (format csv,header true);

-- Include PostgreSQL executor evidence for the index and prefix/range queries.
explain (analyze,buffers,verbose)
 select c.variant_id,c.title,c.sku
 from public.storefront_catalog c
 where c.store_id='a1000000-0000-4000-8000-000000000001'::uuid
 and c.search_document @@ plainto_tsquery('simple','Armoire')
 order by c.title,c.variant_id
 limit 24;

select 'PASS: 100000 SKUs, 2084 unique pages, server-function latencies exported' as result;
