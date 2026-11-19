-- CHR administration: bounded catalog lookup for stores with tens of thousands of references.
-- SECURITY INVOKER and RLS on products/product_variants are the authorization boundary.
create index if not exists idx_chr_admin_products_title_seek
 on public.products(store_id,title,id);
create index if not exists idx_chr_admin_variants_title_seek
 on public.product_variants(store_id,title,id);
create index if not exists idx_chr_admin_products_title_trgm
 on public.products using gin(title extensions.gin_trgm_ops);
create index if not exists idx_chr_admin_variants_sku_trgm
 on public.product_variants using gin(sku extensions.gin_trgm_ops);

create or replace function public.chr_admin_catalog_page(
 p_store_id uuid,p_type text,p_query text default '',
 p_cursor_title text default null,p_cursor_id uuid default null,
 p_limit integer default 50
) returns jsonb
language plpgsql stable security invoker set search_path=''
as $$
declare
 v_limit integer:=greatest(1,least(coalesce(p_limit,50),50));
 v_query text:=trim(coalesce(p_query,''));
 v_rows jsonb:='[]'::jsonb;
 v_row jsonb;
 v_last_title text;
 v_last_id uuid;
 v_count integer:=0;
 v_more boolean:=false;
begin
 if p_type not in ('products','product_variants')
 or p_store_id is null or length(v_query)>100
 or (p_cursor_id is not null and p_cursor_title is null) then
  raise exception 'Invalid admin catalog query' using errcode='22023';
 end if;
 if p_type='products' then
  for v_row in select to_jsonb(p) from public.products p
   where p.store_id=p_store_id
    and (v_query='' or p.title ilike '%'||v_query||'%'
         or p.handle ilike '%'||v_query||'%'
         or p.vendor ilike '%'||v_query||'%')
    and (p_cursor_id is null or (p.title,p.id)>(p_cursor_title,p_cursor_id))
   order by p.title,p.id limit v_limit+1
  loop
   if v_count>=v_limit then v_more:=true;exit;end if;
   v_rows:=v_rows||jsonb_build_array(v_row);
   v_last_title:=v_row->>'title';v_last_id:=(v_row->>'id')::uuid;
   v_count:=v_count+1;
  end loop;
 else
  for v_row in select to_jsonb(v) from public.product_variants v
   where v.store_id=p_store_id
    and (v_query='' or v.title ilike '%'||v_query||'%'
         or v.sku ilike '%'||v_query||'%'
         or v.barcode ilike '%'||v_query||'%')
    and (p_cursor_id is null or (v.title,v.id)>(p_cursor_title,p_cursor_id))
   order by v.title,v.id limit v_limit+1
  loop
   if v_count>=v_limit then v_more:=true;exit;end if;
   v_rows:=v_rows||jsonb_build_array(v_row);
   v_last_title:=v_row->>'title';v_last_id:=(v_row->>'id')::uuid;
   v_count:=v_count+1;
  end loop;
 end if;
 return jsonb_build_object('rows',v_rows,'has_more',v_more,
   'next_cursor',case when v_more then jsonb_build_object('title',v_last_title,'id',v_last_id) else null end);
end $$;
revoke all on function public.chr_admin_catalog_page(uuid,text,text,text,uuid,integer) from public,anon,authenticated;
grant execute on function public.chr_admin_catalog_page(uuid,text,text,text,uuid,integer) to authenticated;
