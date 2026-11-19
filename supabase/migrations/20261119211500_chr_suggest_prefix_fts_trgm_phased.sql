-- CHR 100k: prevent expensive full-catalog suggestion sort.
-- First serve exact title/SKU prefixes using B-tree pattern indexes.
-- Fallback to indexed full text, then trigram contains only when necessary.
-- All queries run SECURITY INVOKER: tenant RLS remains authoritative.
create index if not exists idx_chr_catalog_title_prefix
 on public.storefront_catalog(store_id,(lower(title)) text_pattern_ops);
create index if not exists idx_chr_catalog_sku_prefix
 on public.storefront_catalog(store_id,(lower(sku)) text_pattern_ops);

create or replace function public.chr_catalog_suggest(
 p_slug text,p_query text,p_limit integer default 5
) returns jsonb language plpgsql stable security invoker set search_path=''
as $$
declare
 v_store uuid;
 v_q text:=trim(coalesce(p_query,''));
 v_lower_q text;
 v_limit integer:=greatest(1,least(coalesce(p_limit,5),8));
 v_results jsonb:='[]'::jsonb;
 v_part jsonb;
begin
 if length(v_q) not between 2 and 80 or length(coalesce(p_slug,''))>64 then
  return '[]'::jsonb;
 end if;
 v_lower_q:=lower(v_q);
 select s.store_id into v_store from public.storefront_settings s
 where s.public_slug=p_slug limit 1;
 if v_store is null then return '[]'::jsonb;end if;

 -- Resolve title/SKU prefixes first. This avoids heavy GIN and sorting for
 -- the vast majority of normal product-search use cases.
 with candidates as (
  (
   select c.variant_id,c.product_handle,c.title,c.variant_title,c.sku,c.vendor,
          c.category,c.price_minor,c.image_path,c.image_alt,0 as priority
   from public.storefront_catalog c
   where c.store_id=v_store and lower(c.title) like v_lower_q||'%'
   order by c.title,c.variant_id limit v_limit
  )
  union all
  (
   select c.variant_id,c.product_handle,c.title,c.variant_title,c.sku,c.vendor,
          c.category,c.price_minor,c.image_path,c.image_alt,1 as priority
   from public.storefront_catalog c
   where c.store_id=v_store and lower(c.sku) like v_lower_q||'%'
   order by c.title,c.variant_id limit v_limit
  )
 ), deduplicated as (
  select distinct on (variant_id) *
  from candidates order by variant_id,priority
 )
 select coalesce(
   jsonb_agg(to_jsonb(x)-'priority' order by x.priority,x.title,x.variant_id),
   '[]'::jsonb
 ) into v_results
 from (
  select * from deduplicated order by priority,title,variant_id limit v_limit
 ) x;
 if jsonb_array_length(v_results)>=v_limit then return v_results;end if;

 -- Indexed FTS for terms in the middle of title/categories/SKU.
 select coalesce(jsonb_agg(to_jsonb(x) order by x.title,x.variant_id),'[]'::jsonb)
 into v_part
 from (
  select c.variant_id,c.product_handle,c.title,c.variant_title,c.sku,c.vendor,
         c.category,c.price_minor,c.image_path,c.image_alt
  from public.storefront_catalog c
  where c.store_id=v_store
   and c.search_document @@ pg_catalog.plainto_tsquery('simple'::regconfig,v_q)
   and not exists(
    select 1 from pg_catalog.jsonb_array_elements(v_results) z
    where z->>'variant_id'=c.variant_id::text)
  order by c.title,c.variant_id
  limit (v_limit-jsonb_array_length(v_results))
 ) x;
 v_results:=v_results||v_part;
 if jsonb_array_length(v_results)>=v_limit then return v_results;end if;

 -- Trigram contains fallback for incomplete words and non-token matches.
 if length(v_q)>=3 then
  select coalesce(jsonb_agg(to_jsonb(x) order by x.title,x.variant_id),'[]'::jsonb)
  into v_part
  from (
   select c.variant_id,c.product_handle,c.title,c.variant_title,c.sku,c.vendor,
          c.category,c.price_minor,c.image_path,c.image_alt
   from public.storefront_catalog c
   where c.store_id=v_store and c.search_text ilike '%'||v_q||'%'
    and not exists(
     select 1 from pg_catalog.jsonb_array_elements(v_results) z
     where z->>'variant_id'=c.variant_id::text)
   order by c.title,c.variant_id
   limit (v_limit-jsonb_array_length(v_results))
  ) x;
  v_results:=v_results||v_part;
 end if;
 return v_results;
end $$;
revoke all on function public.chr_catalog_suggest(text,text,integer)
 from public,anon,authenticated;
grant execute on function public.chr_catalog_suggest(text,text,integer)
 to anon,authenticated;
