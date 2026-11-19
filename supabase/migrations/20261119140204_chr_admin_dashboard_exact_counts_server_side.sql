-- CHR: accurate dashboard metrics at scale without loading N table rows into JavaScript.
-- SECURITY INVOKER keeps all source-table RLS checks in force.
create or replace function public.chr_admin_dashboard_counts(p_store_id uuid)
returns jsonb language sql stable security invoker set search_path=''
as $$
 select jsonb_build_object(
  'products',(select count(*) from public.products p where p.store_id=p_store_id),
  'variants',(select count(*) from public.product_variants v where v.store_id=p_store_id),
  'customers',(select count(*) from public.customers c where c.store_id=p_store_id),
  'orders',(select count(*) from public.orders o where o.store_id=p_store_id),
  'orders_open',(select count(*) from public.orders o where o.store_id=p_store_id and o.status='open'),
  'locations',(select count(*) from public.locations l where l.store_id=p_store_id),
  'inventory_low',(select count(*) from public.inventory_levels i where i.store_id=p_store_id and i.on_hand-i.reserved<3),
  'paid_order_value_minor',(select coalesce(sum(o.total_minor),0) from public.orders o
      where o.store_id=p_store_id and o.payment_status in ('paid','partially_refunded'))
 );
$$;
revoke all on function public.chr_admin_dashboard_counts(uuid) from public,anon,authenticated;
grant execute on function public.chr_admin_dashboard_counts(uuid) to authenticated;
