-- AXIUM Commerce OS / CHR — foundational multi-tenant commerce schema
-- Deliberately NO payment/stock/order direct write API: business commands must be transactional.
-- All public tables have RLS; no anon grants; no application secrets.
create schema if not exists app_private;
revoke all on schema app_private from public;
grant usage on schema app_private to authenticated;

create table if not exists public.stores (
 id uuid primary key default gen_random_uuid(), owner_user_id uuid not null references auth.users(id), slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'), name text not null, currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'), timezone text not null default 'Europe/Paris', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.store_members (
 store_id uuid not null references public.stores(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, role text not null check (role in ('admin','manager','support','viewer')), status text not null default 'active' check (status in ('active','invited','suspended')), created_at timestamptz not null default now(), primary key (store_id,user_id)
);

create table if not exists public.products (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), title text not null check (length(trim(title)) > 0), handle text not null, description text, status text not null default 'draft' check (status in ('draft','active','archived')), vendor text, product_type text, tags text[] not null default '{}', metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'), created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (store_id,handle), unique (store_id,id)
);

create table if not exists public.product_variants (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, product_id uuid not null, title text not null default 'Par défaut', sku text, barcode text, options jsonb not null default '{}'::jsonb check (jsonb_typeof(options)='object'), price_minor bigint not null default 0 check (price_minor >= 0), compare_at_minor bigint check (compare_at_minor >= 0), cost_minor bigint check (cost_minor >= 0), weight_grams integer not null default 0 check (weight_grams >= 0), requires_shipping boolean not null default true, taxable boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), foreign key (store_id,product_id) references public.products(store_id,id) on delete restrict, unique (store_id,id), unique (store_id,sku)
);

create table if not exists public.collections (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), title text not null, handle text not null, description text, type text not null default 'manual' check (type in ('manual','automated')), rule_logic text not null default 'all' check (rule_logic in ('all','any')), rules jsonb not null default '[]'::jsonb check (jsonb_typeof(rules)='array'), status text not null default 'active' check (status in ('active','archived')), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (store_id,handle), unique (store_id,id)
);

create table if not exists public.collection_products (
 store_id uuid not null references public.stores(id), collection_id uuid not null, product_id uuid not null, position integer not null default 0, created_at timestamptz not null default now(), primary key (store_id,collection_id,product_id), foreign key (store_id,collection_id) references public.collections(store_id,id) on delete cascade, foreign key (store_id,product_id) references public.products(store_id,id) on delete cascade
);

create table if not exists public.locations (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), name text not null, address jsonb not null default '{}'::jsonb, active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (store_id,id)
);

create table if not exists public.inventory_levels (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, variant_id uuid not null, location_id uuid not null, on_hand integer not null default 0 check(on_hand >= 0), reserved integer not null default 0 check(reserved >= 0 and reserved <= on_hand), updated_at timestamptz not null default now(), unique (store_id,variant_id,location_id), foreign key (store_id,variant_id) references public.product_variants(store_id,id) on delete restrict, foreign key (store_id,location_id) references public.locations(store_id,id) on delete restrict
);

create table if not exists public.inventory_movements (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), inventory_level_id uuid not null references public.inventory_levels(id), delta integer not null check (delta <> 0), reason text not null, source_type text, source_id uuid, actor_user_id uuid references auth.users(id), created_at timestamptz not null default now()
);

create table if not exists public.customers (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), first_name text, last_name text, email text, phone text, company text, addresses jsonb not null default '[]'::jsonb check(jsonb_typeof(addresses)='array'), marketing_consent boolean not null default false, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (store_id,id)
);

create table if not exists public.orders (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), order_number text not null, customer_id uuid, currency text not null default 'EUR' check(currency ~ '^[A-Z]{3}$'), status text not null default 'draft' check(status in ('draft','open','completed','cancelled')), payment_status text not null default 'pending' check(payment_status in ('pending','authorized','partially_paid','paid','partially_refunded','refunded','failed')), fulfillment_status text not null default 'unfulfilled' check(fulfillment_status in ('unfulfilled','partial','fulfilled','returned')), subtotal_minor bigint not null default 0 check(subtotal_minor>=0), discount_minor bigint not null default 0 check(discount_minor>=0), shipping_minor bigint not null default 0 check(shipping_minor>=0), tax_minor bigint not null default 0 check(tax_minor>=0), total_minor bigint not null default 0 check(total_minor>=0), shipping_address jsonb not null default '{}'::jsonb, placed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(store_id,order_number), unique(store_id,id), foreign key(store_id,customer_id) references public.customers(store_id,id) on delete restrict
);

create table if not exists public.order_lines (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, order_id uuid not null, variant_id uuid, product_title text not null, variant_title text, sku text, quantity integer not null check(quantity > 0), unit_price_minor bigint not null check(unit_price_minor>=0), tax_minor bigint not null default 0 check(tax_minor>=0), discount_minor bigint not null default 0 check(discount_minor>=0), created_at timestamptz not null default now(), foreign key(store_id,order_id) references public.orders(store_id,id) on delete restrict, foreign key(store_id,variant_id) references public.product_variants(store_id,id) on delete restrict
);

create table if not exists public.payment_transactions (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, order_id uuid not null, provider text not null, provider_event_id text, provider_reference text, kind text not null check(kind in ('authorization','capture','refund','void')), status text not null check(status in ('pending','succeeded','failed')), amount_minor bigint not null check(amount_minor>=0), currency text not null check(currency ~ '^[A-Z]{3}$'), created_at timestamptz not null default now(), foreign key(store_id,order_id) references public.orders(store_id,id), unique(store_id,provider,provider_event_id)
);

create table if not exists public.refunds (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, order_id uuid not null, amount_minor bigint not null check(amount_minor>0), status text not null default 'pending' check(status in ('pending','succeeded','failed')), reason text, created_at timestamptz not null default now(), foreign key(store_id,order_id) references public.orders(store_id,id)
);

create table if not exists public.shipping_profiles (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), name text not null, is_general boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(store_id,id)
);

create table if not exists public.shipping_zones (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, profile_id uuid not null, name text not null, countries text[] not null default '{}'::text[], postal_prefixes text[] not null default '{}'::text[], excluded_postal_prefixes text[] not null default '{}'::text[], created_at timestamptz not null default now(), unique(store_id,id), foreign key(store_id,profile_id) references public.shipping_profiles(store_id,id) on delete cascade
);

create table if not exists public.shipping_rates (
 id uuid primary key default gen_random_uuid(), store_id uuid not null, zone_id uuid not null, name text not null, mode text not null check(mode in ('flat','weight','order_value','carrier')), amount_minor bigint not null default 0 check(amount_minor>=0), min_weight_grams integer check(min_weight_grams>=0), max_weight_grams integer check(max_weight_grams>=0), min_order_minor bigint check(min_order_minor>=0), max_order_minor bigint check(max_order_minor>=0), enabled boolean not null default true, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), foreign key(store_id,zone_id) references public.shipping_zones(store_id,id) on delete cascade, check(max_weight_grams is null or min_weight_grams is null or max_weight_grams>=min_weight_grams), check(max_order_minor is null or min_order_minor is null or max_order_minor>=min_order_minor)
);

create table if not exists public.discounts (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), code text, name text not null, type text not null check(type in ('fixed','percentage','free_shipping')), value bigint not null default 0 check(value>=0), valid_from timestamptz, valid_until timestamptz, usage_limit integer check(usage_limit>=0), status text not null default 'draft' check(status in ('draft','active','disabled')), rules jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(store_id,code), check(valid_until is null or valid_from is null or valid_until>=valid_from)
);

create table if not exists public.audit_events (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), actor_id uuid references auth.users(id), actor_type text not null check(actor_type in ('human','system','integration','agent')), entity_type text not null, entity_id uuid, action text not null, before_state jsonb, after_state jsonb, correlation_id uuid, created_at timestamptz not null default now()
);

create table if not exists public.action_requests (
 id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id), requested_by uuid references auth.users(id), action_key text not null, action_version integer not null default 1, inputs jsonb not null default '{}'::jsonb, dry_run_result jsonb, status text not null default 'draft' check(status in ('draft','awaiting_approval','approved','executed','failed','cancelled')), approved_by uuid references auth.users(id), executed_at timestamptz, created_at timestamptz not null default now()
);


create or replace function app_private.can_read_store(s uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select (select auth.uid()) is not null
 and (exists(select 1 from public.stores st where st.id=s and st.owner_user_id=(select auth.uid()))
 or exists(select 1 from public.store_members m where m.store_id=s and m.user_id=(select auth.uid()) and m.status='active'));
$$;
create or replace function app_private.can_manage_store(s uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select (select auth.uid()) is not null
 and (exists(select 1 from public.stores st where st.id=s and st.owner_user_id=(select auth.uid()))
 or exists(select 1 from public.store_members m where m.store_id=s and m.user_id=(select auth.uid()) and m.status='active' and m.role in ('admin','manager')));
$$;
create or replace function app_private.is_store_owner(s uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select (select auth.uid()) is not null and exists(select 1 from public.stores st where st.id=s and st.owner_user_id=(select auth.uid()));
$$;
revoke all on function app_private.can_read_store(uuid), app_private.can_manage_store(uuid), app_private.is_store_owner(uuid) from public;
grant execute on function app_private.can_read_store(uuid), app_private.can_manage_store(uuid), app_private.is_store_owner(uuid) to authenticated;

alter table public.stores enable row level security;
create policy stores_select on public.stores for select to authenticated using (app_private.can_read_store(id));
create policy stores_insert on public.stores for insert to authenticated with check (owner_user_id = (select auth.uid()));
create policy stores_update on public.stores for update to authenticated using (app_private.is_store_owner(id)) with check (app_private.is_store_owner(id));
revoke all on public.stores from anon, authenticated;
grant select, insert, update on public.stores to authenticated;

alter table public.store_members enable row level security;
create policy store_members_select on public.store_members for select to authenticated using (app_private.can_read_store(store_id));
create policy store_members_insert on public.store_members for insert to authenticated with check (app_private.is_store_owner(store_id));
create policy store_members_update on public.store_members for update to authenticated using (app_private.is_store_owner(store_id)) with check (app_private.is_store_owner(store_id));
create policy store_members_delete on public.store_members for delete to authenticated using (app_private.is_store_owner(store_id));
revoke all on public.store_members from anon, authenticated;
grant select, insert, update, delete on public.store_members to authenticated;

alter table public.products enable row level security;
create policy products_select on public.products for select to authenticated using (app_private.can_read_store(store_id));
create policy products_insert on public.products for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy products_update on public.products for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy products_delete on public.products for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.products from anon, authenticated;
grant select, insert, update, delete on public.products to authenticated;

alter table public.product_variants enable row level security;
create policy product_variants_select on public.product_variants for select to authenticated using (app_private.can_read_store(store_id));
create policy product_variants_insert on public.product_variants for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy product_variants_update on public.product_variants for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy product_variants_delete on public.product_variants for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.product_variants from anon, authenticated;
grant select, insert, update, delete on public.product_variants to authenticated;

alter table public.collections enable row level security;
create policy collections_select on public.collections for select to authenticated using (app_private.can_read_store(store_id));
create policy collections_insert on public.collections for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy collections_update on public.collections for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy collections_delete on public.collections for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.collections from anon, authenticated;
grant select, insert, update, delete on public.collections to authenticated;

alter table public.collection_products enable row level security;
create policy collection_products_select on public.collection_products for select to authenticated using (app_private.can_read_store(store_id));
create policy collection_products_insert on public.collection_products for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy collection_products_update on public.collection_products for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy collection_products_delete on public.collection_products for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.collection_products from anon, authenticated;
grant select, insert, update, delete on public.collection_products to authenticated;

alter table public.locations enable row level security;
create policy locations_select on public.locations for select to authenticated using (app_private.can_read_store(store_id));
create policy locations_insert on public.locations for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy locations_update on public.locations for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy locations_delete on public.locations for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.locations from anon, authenticated;
grant select, insert, update, delete on public.locations to authenticated;

alter table public.inventory_levels enable row level security;
create policy inventory_levels_select on public.inventory_levels for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.inventory_levels from anon, authenticated;
grant select on public.inventory_levels to authenticated;

alter table public.inventory_movements enable row level security;
create policy inventory_movements_select on public.inventory_movements for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.inventory_movements from anon, authenticated;
grant select on public.inventory_movements to authenticated;

alter table public.customers enable row level security;
create policy customers_select on public.customers for select to authenticated using (app_private.can_read_store(store_id));
create policy customers_insert on public.customers for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy customers_update on public.customers for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy customers_delete on public.customers for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.customers from anon, authenticated;
grant select, insert, update, delete on public.customers to authenticated;

alter table public.orders enable row level security;
create policy orders_select on public.orders for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;

alter table public.order_lines enable row level security;
create policy order_lines_select on public.order_lines for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.order_lines from anon, authenticated;
grant select on public.order_lines to authenticated;

alter table public.payment_transactions enable row level security;
create policy payment_transactions_select on public.payment_transactions for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.payment_transactions from anon, authenticated;
grant select on public.payment_transactions to authenticated;

alter table public.refunds enable row level security;
create policy refunds_select on public.refunds for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.refunds from anon, authenticated;
grant select on public.refunds to authenticated;

alter table public.shipping_profiles enable row level security;
create policy shipping_profiles_select on public.shipping_profiles for select to authenticated using (app_private.can_read_store(store_id));
create policy shipping_profiles_insert on public.shipping_profiles for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy shipping_profiles_update on public.shipping_profiles for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy shipping_profiles_delete on public.shipping_profiles for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.shipping_profiles from anon, authenticated;
grant select, insert, update, delete on public.shipping_profiles to authenticated;

alter table public.shipping_zones enable row level security;
create policy shipping_zones_select on public.shipping_zones for select to authenticated using (app_private.can_read_store(store_id));
create policy shipping_zones_insert on public.shipping_zones for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy shipping_zones_update on public.shipping_zones for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy shipping_zones_delete on public.shipping_zones for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.shipping_zones from anon, authenticated;
grant select, insert, update, delete on public.shipping_zones to authenticated;

alter table public.shipping_rates enable row level security;
create policy shipping_rates_select on public.shipping_rates for select to authenticated using (app_private.can_read_store(store_id));
create policy shipping_rates_insert on public.shipping_rates for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy shipping_rates_update on public.shipping_rates for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy shipping_rates_delete on public.shipping_rates for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.shipping_rates from anon, authenticated;
grant select, insert, update, delete on public.shipping_rates to authenticated;

alter table public.discounts enable row level security;
create policy discounts_select on public.discounts for select to authenticated using (app_private.can_read_store(store_id));
create policy discounts_insert on public.discounts for insert to authenticated with check (app_private.can_manage_store(store_id));
create policy discounts_update on public.discounts for update to authenticated using (app_private.can_manage_store(store_id)) with check (app_private.can_manage_store(store_id));
create policy discounts_delete on public.discounts for delete to authenticated using (app_private.can_manage_store(store_id));
revoke all on public.discounts from anon, authenticated;
grant select, insert, update, delete on public.discounts to authenticated;

alter table public.audit_events enable row level security;
create policy audit_events_select on public.audit_events for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.audit_events from anon, authenticated;
grant select on public.audit_events to authenticated;

alter table public.action_requests enable row level security;
create policy action_requests_select on public.action_requests for select to authenticated using (app_private.can_read_store(store_id));
revoke all on public.action_requests from anon, authenticated;
grant select on public.action_requests to authenticated;


create index if not exists idx_products_store_status on public.products (store_id,status,created_at desc);
create index if not exists idx_variants_product on public.product_variants (store_id,product_id);
create index if not exists idx_collections_store on public.collections (store_id,type);
create index if not exists idx_locations_store on public.locations (store_id);
create index if not exists idx_inventory_variant on public.inventory_levels (store_id,variant_id);
create index if not exists idx_movements_store_created on public.inventory_movements (store_id,created_at desc);
create index if not exists idx_customers_store_email on public.customers (store_id,lower(email));
create index if not exists idx_orders_store_created on public.orders (store_id,created_at desc);
create index if not exists idx_order_lines_store_order on public.order_lines (store_id,order_id);
create index if not exists idx_transactions_store_order on public.payment_transactions (store_id,order_id);
create index if not exists idx_refunds_store_order on public.refunds (store_id,order_id);
create index if not exists idx_shipping_zones_store_profile on public.shipping_zones (store_id,profile_id);
create index if not exists idx_shipping_rates_store_zone on public.shipping_rates (store_id,zone_id);
create index if not exists idx_audit_store_created on public.audit_events (store_id,created_at desc);
create index if not exists idx_actions_store_created on public.action_requests (store_id,created_at desc);
