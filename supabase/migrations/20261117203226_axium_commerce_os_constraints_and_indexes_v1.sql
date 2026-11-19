-- Improve referential integrity, auditability and expected lookup plans.
-- Database was empty when these changes were prepared.
alter table public.inventory_levels
  add constraint inventory_levels_store_id_id_key unique (store_id, id);
alter table public.inventory_movements
  drop constraint inventory_movements_inventory_level_id_fkey;
alter table public.inventory_movements
  add constraint inventory_movements_tenant_level_fkey
  foreign key (store_id, inventory_level_id)
  references public.inventory_levels(store_id,id) on delete restrict;

create index if not exists idx_action_requests_approved_by on public.action_requests(approved_by);
create index if not exists idx_action_requests_requested_by on public.action_requests(requested_by);
create index if not exists idx_audit_events_actor on public.audit_events(actor_id);
create index if not exists idx_collection_products_store_product on public.collection_products(store_id,product_id);
create index if not exists idx_inventory_levels_store_location on public.inventory_levels(store_id,location_id);
create index if not exists idx_inventory_movements_actor on public.inventory_movements(actor_user_id);
create index if not exists idx_inventory_movements_level on public.inventory_movements(store_id,inventory_level_id);
create index if not exists idx_order_lines_store_variant on public.order_lines(store_id,variant_id);
create index if not exists idx_orders_store_customer on public.orders(store_id,customer_id);
create index if not exists idx_products_created_by on public.products(created_by);
create index if not exists idx_store_members_user on public.store_members(user_id);
create index if not exists idx_stores_owner on public.stores(owner_user_id);

create or replace function app_private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
create or replace function app_private.forbid_tenant_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.store_id is distinct from old.store_id then
    raise exception 'Changing store_id is prohibited' using errcode = '23514';
  end if;
  return new;
end $$;
create or replace function app_private.forbid_store_owner_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.owner_user_id is distinct from old.owner_user_id then
    raise exception 'Store ownership transfer requires dedicated workflow' using errcode = '23514';
  end if;
  return new;
end $$;
revoke all on function app_private.set_updated_at(), app_private.forbid_tenant_change(), app_private.forbid_store_owner_change() from public;
do $$
declare t text;
begin
  foreach t in array array['stores','products','product_variants','collections','locations','customers','orders','shipping_profiles','shipping_rates','discounts']
  loop
    execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function app_private.set_updated_at()',t,t);
  end loop;
  foreach t in array array['store_members','products','product_variants','collections','locations','customers','orders','shipping_profiles','shipping_zones','shipping_rates','discounts']
  loop
    execute format('create trigger trg_%I_tenant_lock before update on public.%I for each row execute function app_private.forbid_tenant_change()',t,t);
  end loop;
end $$;
create trigger trg_stores_owner_lock before update on public.stores
for each row execute function app_private.forbid_store_owner_change();
