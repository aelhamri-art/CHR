-- CHR: indexed search and seek pagination for a 100k-reference design target.
-- Uses SECURITY INVOKER: PostgreSQL RLS remains authoritative for all reads.
create extension if not exists pg_trgm with schema extensions;

alter table public.storefront_catalog
 add column if not exists search_text text generated always as (
  lower(coalesce(title,'') || ' ' || coalesce(variant_title,'') || ' ' ||
        coalesce(sku,'') || ' ' || coalesce(vendor,'') || ' ' ||
        coalesce(category,'') || ' ' || coalesce(product_handle,''))
 ) stored;

alter table public.storefront_catalog
 add column if not exists search_document tsvector generated always as (
  to_tsvector('simple'::regconfig,
    coalesce(title,'') || ' ' || coalesce(variant_title,'') || ' ' ||
    coalesce(sku,'') || ' ' || coalesce(vendor,'') || ' ' ||
    coalesce(category,'') || ' ' || coalesce(product_handle,''))
 ) stored;

create index if not exists idx_chr_catalog_title_seek
 on public.storefront_catalog(store_id,title,variant_id);
create index if not exists idx_chr_catalog_price_seek
 on public.storefront_catalog(store_id,price_minor,variant_id);
create index if not exists idx_chr_catalog_category_seek
 on public.storefront_catalog(store_id,category,title,variant_id);
create index if not exists idx_chr_catalog_handle
 on public.storefront_catalog(store_id,product_handle,variant_id);
create index if not exists idx_chr_catalog_search_trgm
 on public.storefront_catalog using gin(search_text extensions.gin_trgm_ops);
create index if not exists idx_chr_catalog_search_fts
 on public.storefront_catalog using gin(search_document);

-- Do not expose search_text, internal vectors or cost fields to the API.
-- Read methods project only enumerated public product columns.
create or replace function public.chr_catalog_page(
 p_slug text, p_query text default '', p_category text default null,
 p_sort text default 'name', p_cursor_title text default null,
 p_cursor_price bigint default null, p_cursor_id uuid default null,
 p_limit integer default 24
) returns jsonb
language plpgsql stable security invoker set search_path=''
as $$
declare
 v_store uuid;
 v_query text:=left(trim(coalesce(p_query,'')),120);
 v_limit integer:=greatest(1,least(coalesce(p_limit,24),48));
 v_sort text:=coalesce(p_sort,'name');
 v_row public.storefront_catalog%rowtype;
 v_items jsonb:='[]'::jsonb;
 v_n integer:=0;
 v_more boolean:=false;
 v_last_title text:=null;
 v_last_price bigint:=null;
 v_last_id uuid:=null;
begin
 if length(coalesce(p_query,''))>120 or length(coalesce(p_slug,''))>64 or
   (p_category is not null and length(p_category)>100) or
   v_sort not in ('name','price-low','price-high') then
   raise exception 'Invalid catalog query' using errcode='22023';
 end if;
 if p_cursor_id is not null and
  ((v_sort='name' and p_cursor_title is null) or
  (v_sort<>'name' and p_cursor_price is null)) then
   raise exception 'Incomplete cursor' using errcode='22023';
 end if;
 select s.store_id into v_store from public.storefront_settings s
 where s.public_slug=p_slug limit 1;
 if v_store is null then
   return jsonb_build_object('items','[]'::jsonb,'has_more',false,'next_cursor',null);
 end if;
 if v_sort='name' then
  for v_row in
   select c.* from public.storefront_catalog c
   where c.store_id=v_store
    and (p_category is null or p_category='' or c.category=p_category)
    and (v_query='' or
      c.search_document @@ pg_catalog.plainto_tsquery('simple'::regconfig,v_query)
      or c.search_text ilike '%'||v_query||'%')
    and (p_cursor_id is null or (c.title,c.variant_id)>(p_cursor_title,p_cursor_id))
   order by c.title asc,c.variant_id asc limit v_limit+1
  loop
   if v_n>=v_limit then v_more:=true;exit;end if;
   v_items:=v_items||pg_catalog.jsonb_build_array(
    pg_catalog.to_jsonb(v_row)-'search_document'-'search_text'-'updated_at');
   v_last_title:=v_row.title;v_last_price:=v_row.price_minor;v_last_id:=v_row.variant_id;
   v_n:=v_n+1;
  end loop;
 elsif v_sort='price-low' then
  for v_row in
   select c.* from public.storefront_catalog c
   where c.store_id=v_store
    and (p_category is null or p_category='' or c.category=p_category)
    and (v_query='' or c.search_document @@ pg_catalog.plainto_tsquery('simple'::regconfig,v_query)
      or c.search_text ilike '%'||v_query||'%')
    and (p_cursor_id is null or (c.price_minor,c.variant_id)>(p_cursor_price,p_cursor_id))
   order by c.price_minor asc,c.variant_id asc limit v_limit+1
  loop
   if v_n>=v_limit then v_more:=true;exit;end if;
   v_items:=v_items||pg_catalog.jsonb_build_array(
    pg_catalog.to_jsonb(v_row)-'search_document'-'search_text'-'updated_at');
   v_last_title:=v_row.title;v_last_price:=v_row.price_minor;v_last_id:=v_row.variant_id;
   v_n:=v_n+1;
  end loop;
 else
  for v_row in
   select c.* from public.storefront_catalog c
   where c.store_id=v_store
    and (p_category is null or p_category='' or c.category=p_category)
    and (v_query='' or c.search_document @@ pg_catalog.plainto_tsquery('simple'::regconfig,v_query)
      or c.search_text ilike '%'||v_query||'%')
    and (p_cursor_id is null or
      c.price_minor<p_cursor_price or
      (c.price_minor=p_cursor_price and c.variant_id>p_cursor_id))
   order by c.price_minor desc,c.variant_id asc limit v_limit+1
  loop
   if v_n>=v_limit then v_more:=true;exit;end if;
   v_items:=v_items||pg_catalog.jsonb_build_array(
    pg_catalog.to_jsonb(v_row)-'search_document'-'search_text'-'updated_at');
   v_last_title:=v_row.title;v_last_price:=v_row.price_minor;v_last_id:=v_row.variant_id;
   v_n:=v_n+1;
  end loop;
 end if;
 return jsonb_build_object(
  'items',v_items,'has_more',v_more,
  'next_cursor',case when v_more then jsonb_build_object(
    'title',v_last_title,'price',v_last_price,'id',v_last_id) else null end);
end $$;

create or replace function public.chr_catalog_suggest(
 p_slug text,p_query text,p_limit integer default 5
) returns jsonb
language sql stable security invoker set search_path=''
as $$
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb)
 from (
  select c.variant_id,c.product_handle,c.title,c.variant_title,c.sku,
         c.vendor,c.category,c.price_minor,c.image_path,c.image_alt
  from public.storefront_catalog c
  join public.storefront_settings s on s.store_id=c.store_id
  where s.public_slug=p_slug
    and length(trim(coalesce(p_query,''))) between 2 and 80
    and (
      c.search_document @@ pg_catalog.plainto_tsquery('simple'::regconfig,left(trim(p_query),80))
      or c.search_text ilike '%'||left(trim(p_query),80)||'%')
  order by case when lower(c.title) like lower(trim(p_query))||'%' then 0 else 1 end,
           c.title asc,c.variant_id asc
  limit greatest(1,least(coalesce(p_limit,5),8))
 ) t;
$$;

create or replace function public.chr_catalog_product(
 p_slug text,p_handle text
) returns jsonb
language sql stable security invoker set search_path=''
as $$
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb)
 from (
  select c.store_id,c.product_id,c.variant_id,c.product_handle,c.title,c.description,
   c.vendor,c.category,c.variant_title,c.sku,c.price_minor,c.weight_grams,
   c.image_path,c.image_alt
  from public.storefront_catalog c
  join public.storefront_settings s on s.store_id=c.store_id
  where s.public_slug=p_slug and
   length(p_handle) between 1 and 180 and c.product_handle=p_handle
  order by c.variant_id
  limit 200
 ) t;
$$;

create or replace function public.chr_catalog_cart_lines(
 p_slug text,p_ids uuid[]
) returns jsonb
language plpgsql stable security invoker set search_path=''
as $$
declare v_result jsonb;
begin
 if p_ids is null or cardinality(p_ids)>100 then
  raise exception 'Too many cart references' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) into v_result from (
  select c.store_id,c.product_id,c.variant_id,c.product_handle,c.title,c.variant_title,
   c.sku,c.price_minor,c.image_path,c.image_alt,c.category,c.weight_grams
  from public.storefront_catalog c
  join public.storefront_settings s on s.store_id=c.store_id
  where s.public_slug=p_slug and c.variant_id=any(p_ids)
  order by c.title limit 100
 ) t;
 return v_result;
end $$;

create or replace function public.chr_catalog_categories(
 p_slug text
) returns jsonb
language sql stable security invoker set search_path=''
as $$
 select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from (
  select c.category as name,count(*)::integer as reference_count
  from public.storefront_catalog c
  join public.storefront_settings s on s.store_id=c.store_id
  where s.public_slug=p_slug and c.category is not null and c.category<>''
  group by c.category order by c.category limit 100
 ) t;
$$;

revoke all on function
 public.chr_catalog_page(text,text,text,text,text,bigint,uuid,integer),
 public.chr_catalog_suggest(text,text,integer),
 public.chr_catalog_product(text,text),
 public.chr_catalog_cart_lines(text,uuid[]),
 public.chr_catalog_categories(text)
 from public,anon,authenticated;
grant execute on function
 public.chr_catalog_page(text,text,text,text,text,bigint,uuid,integer),
 public.chr_catalog_suggest(text,text,integer),
 public.chr_catalog_product(text,text),
 public.chr_catalog_cart_lines(text,uuid[]),
 public.chr_catalog_categories(text)
 to anon,authenticated;
