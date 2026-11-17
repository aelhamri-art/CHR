-- CHR Storefront V1: explicitly published public catalog + private customer data
-- No payment card data is collected or stored in this schema.
create table public.storefront_settings(
 store_id uuid primary key references public.stores(id) on delete cascade,
 public_slug text not null unique check(public_slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
 brand_name text not null default 'CHR' check(length(brand_name) between 2 and 80),
 eyebrow text not null default 'ÉQUIPEMENTS POUR LES PROFESSIONNELS',
 headline text not null default 'Votre cuisine. Votre exigence.',
 subline text not null default 'Découvrez une sélection d’équipements pour les professionnels de la restauration.',
 contact_email text,
 hero_image_path text,
 published boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.storefront_settings enable row level security;
create policy storefront_settings_public_read on public.storefront_settings for select to anon,authenticated
using (published);
create policy storefront_settings_staff_read on public.storefront_settings for select to authenticated
using(app_private.can_read_store(store_id));
create policy storefront_settings_staff_insert on public.storefront_settings for insert to authenticated
with check(app_private.can_manage_store(store_id));
create policy storefront_settings_staff_update on public.storefront_settings for update to authenticated
using(app_private.can_manage_store(store_id))
with check(app_private.can_manage_store(store_id));
revoke all on public.storefront_settings from anon,authenticated;
grant select on public.storefront_settings to anon;
grant select,insert,update on public.storefront_settings to authenticated;
create trigger trg_storefront_settings_updated_at before update on public.storefront_settings for each row execute function app_private.set_updated_at();
create trigger trg_storefront_settings_tenant_lock before update on public.storefront_settings for each row execute function app_private.forbid_tenant_change();
-- publish remains OFF until product photography, policies and branding are approved.
insert into public.storefront_settings(store_id,public_slug)
select id,'chr' from public.stores where slug='chr'
on conflict do nothing;

-- Projection table contains only public, sellable data. Never exposes cost_minor,
-- private metadata, user/finance tables or variants of drafts/archived products.
create table public.storefront_catalog(
 store_id uuid not null references public.stores(id) on delete cascade,
 product_id uuid not null,
 variant_id uuid not null,
 product_handle text not null,
 title text not null,
 description text,
 vendor text,
 category text,
 variant_title text not null,
 sku text,
 price_minor bigint not null check(price_minor>=0),
 weight_grams integer not null check(weight_grams>=0),
 image_path text,
 image_alt text,
 updated_at timestamptz not null default now(),
 primary key(store_id,variant_id),
 foreign key(store_id,product_id) references public.products(store_id,id) on delete cascade,
 foreign key(store_id,variant_id) references public.product_variants(store_id,id) on delete cascade
);
create index storefront_catalog_product_idx on public.storefront_catalog(store_id,product_id);
create index storefront_catalog_search_idx on public.storefront_catalog(store_id,category,vendor);
alter table public.storefront_catalog enable row level security;
create policy storefront_catalog_public_read on public.storefront_catalog for select to anon,authenticated
using(exists(select 1 from public.storefront_settings s where s.store_id=storefront_catalog.store_id and s.published));
revoke all on public.storefront_catalog from anon,authenticated;
grant select on public.storefront_catalog to anon,authenticated;

create or replace function app_private.refresh_storefront_catalog(p_product uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare p record;
begin
 delete from public.storefront_catalog where product_id=p_product;
 select id,store_id,title,handle,description,vendor,product_type,status into p
 from public.products where id=p_product;
 if not found or p.status <> 'active' then return;end if;
 insert into public.storefront_catalog(store_id,product_id,variant_id,product_handle,title,
 description,vendor,category,variant_title,sku,price_minor,weight_grams,image_path,image_alt)
 select p.store_id,p.id,v.id,p.handle,p.title,p.description,p.vendor,p.product_type,
 v.title,v.sku,v.price_minor,v.weight_grams,
 (select m.storage_path from public.product_media m where m.store_id=p.store_id and m.product_id=p.id order by m.position,m.created_at limit 1),
 (select m.alt_text from public.product_media m where m.store_id=p.store_id and m.product_id=p.id order by m.position,m.created_at limit 1)
 from public.product_variants v where v.store_id=p.store_id and v.product_id=p.id;
end $$;
revoke all on function app_private.refresh_storefront_catalog(uuid) from public,anon,authenticated;
create or replace function app_private.sync_storefront_catalog()
returns trigger language plpgsql security definer set search_path=''
as $$
declare previous_id uuid; next_id uuid;
begin
 if tg_table_name='products' then
  previous_id:=case when tg_op<>'INSERT' then old.id else null end;
  next_id:=case when tg_op<>'DELETE' then new.id else null end;
 else
  previous_id:=case when tg_op<>'INSERT' then old.product_id else null end;
  next_id:=case when tg_op<>'DELETE' then new.product_id else null end;
 end if;
 if previous_id is not null then perform app_private.refresh_storefront_catalog(previous_id);end if;
 if next_id is not null and next_id is distinct from previous_id
 then perform app_private.refresh_storefront_catalog(next_id);end if;
 return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function app_private.sync_storefront_catalog() from public,anon,authenticated;
create trigger trg_products_storefront after insert or update or delete on public.products
for each row execute function app_private.sync_storefront_catalog();
create trigger trg_variants_storefront after insert or update or delete on public.product_variants
for each row execute function app_private.sync_storefront_catalog();
create trigger trg_product_media_storefront after insert or update or delete on public.product_media
for each row execute function app_private.sync_storefront_catalog();
do $$
declare p uuid;
begin for p in select id from public.products loop perform app_private.refresh_storefront_catalog(p);end loop;end $$;

-- Customer accounts are deliberately separate from employee/store_members roles.
create table public.storefront_customers(
 store_id uuid not null references public.stores(id),
 user_id uuid not null references auth.users(id) on delete cascade,
 first_name text,
 last_name text,
 company_name text,
 phone text,
 marketing_opt_in boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 primary key(store_id,user_id)
);
create table public.storefront_addresses(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 user_id uuid not null,
 label text not null default 'Adresse',
 recipient text not null,
 company text,
 line1 text not null,
 line2 text,
 postal_code text not null,
 city text not null,
 country text not null default 'FR' check(country ~ '^[A-Z]{2}$'),
 phone text,
 is_default boolean not null default false,
 created_at timestamptz not null default now(),
 foreign key(store_id,user_id) references public.storefront_customers(store_id,user_id) on delete cascade
);
create index storefront_addresses_owner_idx on public.storefront_addresses(store_id,user_id);
create table public.storefront_wishlist(
 store_id uuid not null,
 user_id uuid not null,
 variant_id uuid not null,
 created_at timestamptz not null default now(),
 primary key(store_id,user_id,variant_id),
 foreign key(store_id,user_id) references public.storefront_customers(store_id,user_id) on delete cascade,
 foreign key(store_id,variant_id) references public.product_variants(store_id,id) on delete cascade
);
create table public.storefront_saved_cart(
 store_id uuid not null,
 user_id uuid not null,
 variant_id uuid not null,
 quantity integer not null check(quantity between 1 and 9999),
 updated_at timestamptz not null default now(),
 primary key(store_id,user_id,variant_id),
 foreign key(store_id,user_id) references public.storefront_customers(store_id,user_id) on delete cascade,
 foreign key(store_id,variant_id) references public.product_variants(store_id,id) on delete cascade
);
create table public.storefront_quotes(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.stores(id),
 user_id uuid not null references auth.users(id),
 idempotency_key uuid not null,
 company_name text,
 contact_email text not null,
 notes text,
 lines jsonb not null check(jsonb_typeof(lines)='array'),
 estimate_minor bigint not null check(estimate_minor>=0),
 status text not null default 'new' check(status in ('new','reviewing','replied','closed')),
 created_at timestamptz not null default now(),
 unique(store_id,user_id,idempotency_key)
);
create index storefront_quotes_owner_idx on public.storefront_quotes(store_id,user_id,created_at desc);
do $$
declare t text;
begin
 foreach t in array array['storefront_customers','storefront_addresses','storefront_wishlist','storefront_saved_cart','storefront_quotes'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
 end loop;
end $$;
create policy customer_self_read on public.storefront_customers for select to authenticated
using(user_id=(select auth.uid()));
create policy customer_self_create on public.storefront_customers for insert to authenticated
with check(user_id=(select auth.uid()) and exists(select 1 from public.storefront_settings s where s.store_id=storefront_customers.store_id and s.published));
create policy customer_self_update on public.storefront_customers for update to authenticated
using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy address_self_read on public.storefront_addresses for select to authenticated using(user_id=(select auth.uid()));
create policy address_self_insert on public.storefront_addresses for insert to authenticated with check(user_id=(select auth.uid()));
create policy address_self_update on public.storefront_addresses for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy address_self_delete on public.storefront_addresses for delete to authenticated using(user_id=(select auth.uid()));
create policy wishlist_self_read on public.storefront_wishlist for select to authenticated using(user_id=(select auth.uid()));
create policy wishlist_self_insert on public.storefront_wishlist for insert to authenticated with check(user_id=(select auth.uid()));
create policy wishlist_self_delete on public.storefront_wishlist for delete to authenticated using(user_id=(select auth.uid()));
create policy cart_self_read on public.storefront_saved_cart for select to authenticated using(user_id=(select auth.uid()));
create policy cart_self_insert on public.storefront_saved_cart for insert to authenticated with check(user_id=(select auth.uid()));
create policy cart_self_update on public.storefront_saved_cart for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy cart_self_delete on public.storefront_saved_cart for delete to authenticated using(user_id=(select auth.uid()));
create policy quote_self_read on public.storefront_quotes for select to authenticated
using(user_id=(select auth.uid()) or app_private.can_view_customers(store_id));
create policy quote_staff_update on public.storefront_quotes for update to authenticated
using(app_private.can_manage_store(store_id)) with check(app_private.can_manage_store(store_id));
grant select,insert,update on public.storefront_customers to authenticated;
grant select,insert,update,delete on public.storefront_addresses to authenticated;
grant select,insert,delete on public.storefront_wishlist to authenticated;
grant select,insert,update,delete on public.storefront_saved_cart to authenticated;
grant select,update on public.storefront_quotes to authenticated;

create or replace function app_private.prevent_customer_identity_change() returns trigger
language plpgsql set search_path='' as $$
begin
 if new.store_id is distinct from old.store_id or new.user_id is distinct from old.user_id then
  raise exception 'Identity is immutable' using errcode='23514';
 end if;
 return new;
end $$;
do $$
declare t text;
begin
 foreach t in array array['storefront_customers','storefront_addresses','storefront_saved_cart','storefront_quotes'] loop
  execute format('create trigger trg_%I_owner_lock before update on public.%I for each row execute function app_private.prevent_customer_identity_change()',t,t);
 end loop;
end $$;

-- Quotation request: authenticated, rate-limited, revalidated against published prices.
create or replace function public.request_storefront_quote(
 p_store_id uuid,p_lines jsonb,p_company text,p_email text,p_notes text,p_key uuid
) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_id uuid;v_item jsonb;v_qty int;v_id_variant uuid;v_product record;
 v_snapshot jsonb:='[]'::jsonb;v_total bigint:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 if not exists(select 1 from public.storefront_settings where store_id=p_store_id and published=true)
 then raise exception 'Store not published' using errcode='23514';end if;
 if not exists(select 1 from public.storefront_customers where store_id=p_store_id and user_id=auth.uid())
 then raise exception 'Customer profile required' using errcode='42501';end if;
 if p_key is null or p_lines is null or jsonb_typeof(p_lines)<>'array'
 or jsonb_array_length(p_lines) not between 1 and 25
 or length(trim(coalesce(p_email,'')))<5 or position('@' in p_email)=0
 or length(coalesce(p_notes,''))>3000 then raise exception 'Invalid quote request' using errcode='22023';end if;
 select id into v_id from public.storefront_quotes where store_id=p_store_id and user_id=auth.uid() and idempotency_key=p_key;
 if found then return jsonb_build_object('quote_id',v_id,'status','already_created');end if;
 if (select count(*) from public.storefront_quotes where user_id=auth.uid() and store_id=p_store_id and created_at>now()-interval '1 day')>=10
 then raise exception 'Too many quote requests today' using errcode='22023';end if;
 for v_item in select value from jsonb_array_elements(p_lines) loop
  if jsonb_typeof(v_item)<>'object'
  or coalesce(v_item->>'variant_id','') !~ '^[0-9a-fA-F-]{36}$'
  or coalesce(v_item->>'quantity','') !~ '^[0-9]+$' then
   raise exception 'Invalid quote line' using errcode='22023';end if;
  v_id_variant:=(v_item->>'variant_id')::uuid;
  v_qty:=(v_item->>'quantity')::int;
  if v_qty<1 or v_qty>999 then raise exception 'Invalid quantity' using errcode='22023';end if;
  select title,variant_title,price_minor,sku into v_product
  from public.storefront_catalog where store_id=p_store_id and variant_id=v_id_variant;
  if not found then raise exception 'Unpublished item in quote' using errcode='23514';end if;
  v_total:=v_total + (v_product.price_minor*v_qty);
  v_snapshot:=v_snapshot||jsonb_build_array(jsonb_build_object(
   'variant_id',v_id_variant,'title',v_product.title,'variant_title',v_product.variant_title,
   'sku',v_product.sku,'quantity',v_qty,'unit_price_minor',v_product.price_minor));
 end loop;
 insert into public.storefront_quotes(store_id,user_id,idempotency_key,company_name,contact_email,notes,lines,estimate_minor)
 values(p_store_id,auth.uid(),p_key,left(trim(coalesce(p_company,'')),180),left(trim(p_email),254),
 p_notes,v_snapshot,v_total) returning id into v_id;
 return jsonb_build_object('quote_id',v_id,'status','created','estimate_minor',v_total);
end $$;
revoke all on function public.request_storefront_quote(uuid,jsonb,text,text,text,uuid) from public,anon;
grant execute on function public.request_storefront_quote(uuid,jsonb,text,text,text,uuid) to authenticated;
