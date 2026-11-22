-- AXIUM OS CHR / P0: owner-configurable commercial rules, never auth bypasses.
-- Deliberately non-destructive: existing orders, stock, and quotes remain unchanged.
create table if not exists public.chr_business_policies (
 store_id uuid primary key references public.stores(id) on delete cascade,
 allow_negotiated_prices boolean not null default true,
 max_price_reduction_bps integer not null default 4000
   check(max_price_reduction_bps between 0 and 10000),
 quote_line_limit integer not null default 250
   check(quote_line_limit between 1 and 500),
 allow_backorder_quotes boolean not null default true,
 allow_pickup_quotes boolean not null default true,
 updated_at timestamptz not null default now(),
 updated_by uuid,
 policy_revision integer not null default 1
   check(policy_revision>=1)
);
alter table public.chr_business_policies enable row level security;
revoke all on public.chr_business_policies from public,anon,authenticated;
grant select,insert,update on public.chr_business_policies to authenticated;
create policy chr_business_policies_read on public.chr_business_policies
 for select to authenticated using (app_private.can_read_store(store_id));
create policy chr_business_policies_insert on public.chr_business_policies
 for insert to authenticated with check (app_private.is_store_owner(store_id));
create policy chr_business_policies_update on public.chr_business_policies
 for update to authenticated
 using (app_private.is_store_owner(store_id))
 with check (app_private.is_store_owner(store_id));

create or replace function app_private.chr_policy_revision_guard()
returns trigger language plpgsql set search_path=''
as $body$
begin
 if tg_op='UPDATE' then
  if new.store_id is distinct from old.store_id then
   raise exception 'Cannot change tenant of commercial policy' using errcode='23514';
  end if;
  -- Prevent spoofing the audit actor / revision. The revision is always server owned.
  new.policy_revision:=old.policy_revision+1;
 end if;
 new.updated_by:=auth.uid();
 new.updated_at:=now();
 return new;
end $body$;
drop trigger if exists trg_chr_policy_guard on public.chr_business_policies;
create trigger trg_chr_policy_guard before insert or update
 on public.chr_business_policies
 for each row execute function app_private.chr_policy_revision_guard();

create table if not exists public.chr_order_price_agreements(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 order_id uuid not null,
 variant_id uuid not null,
 base_unit_minor bigint not null check(base_unit_minor>=0),
 agreed_unit_minor bigint not null check(agreed_unit_minor>=0),
 quantity integer not null check(quantity>0),
 reason text not null check(length(btrim(reason)) between 8 and 500),
 approved_by uuid not null,
 created_at timestamptz not null default now(),
 unique(store_id,order_id,variant_id),
 foreign key(store_id,order_id) references public.orders(store_id,id) on delete restrict,
 foreign key(store_id,variant_id) references public.product_variants(store_id,id)
);
create index if not exists idx_chr_agreements_store_order
 on public.chr_order_price_agreements(store_id,order_id);
alter table public.chr_order_price_agreements enable row level security;
revoke all on public.chr_order_price_agreements from public,anon,authenticated;
grant select on public.chr_order_price_agreements to authenticated;
create policy chr_order_agreements_select on public.chr_order_price_agreements
 for select to authenticated using(app_private.can_view_finance(store_id));
-- There is deliberately no INSERT/UPDATE/DELETE policy. Only the authorized
-- create_order() RPC may atomically create a negotiated price snapshot.
