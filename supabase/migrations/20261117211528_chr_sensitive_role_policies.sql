-- CHR roles : protect personal and financial data from read-only viewers.
create or replace function app_private.can_view_customers(s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (select auth.uid()) is not null and
 (exists(select 1 from public.stores t where t.id=s and t.owner_user_id=(select auth.uid()))
  or exists(select 1 from public.store_members m where m.store_id=s
    and m.user_id=(select auth.uid()) and m.status='active' and m.role in ('admin','manager','support')));
$$;
create or replace function app_private.can_view_finance(s uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (select auth.uid()) is not null and
 (exists(select 1 from public.stores t where t.id=s and t.owner_user_id=(select auth.uid()))
  or exists(select 1 from public.store_members m where m.store_id=s
    and m.user_id=(select auth.uid()) and m.status='active' and m.role in ('admin','manager')));
$$;
revoke all on function app_private.can_view_customers(uuid),app_private.can_view_finance(uuid) from public;
grant execute on function app_private.can_view_customers(uuid),app_private.can_view_finance(uuid) to authenticated;
drop policy if exists customers_select on public.customers;
create policy customers_select on public.customers for select to authenticated using(app_private.can_view_customers(store_id));
drop policy if exists payment_transactions_select on public.payment_transactions;
create policy payment_transactions_select on public.payment_transactions for select to authenticated using(app_private.can_view_finance(store_id));
drop policy if exists refunds_select on public.refunds;
create policy refunds_select on public.refunds for select to authenticated using(app_private.can_view_finance(store_id));
drop policy if exists audit_events_select on public.audit_events;
create policy audit_events_select on public.audit_events for select to authenticated using(app_private.can_view_finance(store_id));
drop policy if exists action_requests_select on public.action_requests;
create policy action_requests_select on public.action_requests for select to authenticated using(app_private.can_view_finance(store_id));
