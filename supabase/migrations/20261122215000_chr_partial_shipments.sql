-- AXIUM OS CHR: atomic partial dispatches, with immutable per-SKU movements.
-- A single order can be dispatched across several packages without changing
-- the original commercial terms or silently shipping unreserved stock.
create unique index if not exists uq_chr_order_lines_store_id_id
 on public.order_lines(store_id,id);

create table if not exists public.chr_shipments(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 order_id uuid not null,
 request_key uuid not null,
 request_lines jsonb not null check (jsonb_typeof(request_lines)='array'),
 carrier text not null check(length(btrim(carrier)) between 2 and 120),
 tracking_reference text not null check(length(btrim(tracking_reference)) between 4 and 200),
 status text not null default 'dispatched' check(status='dispatched'),
 actor_id uuid not null,
 created_at timestamptz not null default now(),
 unique(store_id,id),
 unique(store_id,order_id,request_key),
 foreign key(store_id,order_id) references public.orders(store_id,id) on delete restrict
);
create index if not exists idx_chr_shipments_order_created on public.chr_shipments(store_id,order_id,created_at desc);

create table if not exists public.chr_shipment_lines(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 shipment_id uuid not null,
 order_line_id uuid not null,
 quantity integer not null check(quantity>0),
 created_at timestamptz not null default now(),
 unique(store_id,shipment_id,order_line_id),
 foreign key(store_id,shipment_id) references public.chr_shipments(store_id,id) on delete restrict,
 foreign key(store_id,order_line_id) references public.order_lines(store_id,id) on delete restrict
);
create index if not exists idx_chr_ship_lines_order_line
 on public.chr_shipment_lines(store_id,order_line_id);

alter table public.chr_shipments enable row level security;
alter table public.chr_shipment_lines enable row level security;
revoke all on public.chr_shipments,public.chr_shipment_lines from public,anon,authenticated;
grant select on public.chr_shipments,public.chr_shipment_lines to authenticated;
create policy chr_shipments_read on public.chr_shipments
 for select to authenticated using(app_private.can_read_store(store_id));
create policy chr_shipment_lines_read on public.chr_shipment_lines
 for select to authenticated using(app_private.can_read_store(store_id));

create or replace function public.chr_dispatch_order_lines(
 p_store_id uuid,p_order_id uuid,p_lines jsonb,
 p_carrier text,p_tracking text,p_request_key uuid
) returns jsonb language plpgsql security definer set search_path=''
as $dispatch$
declare
 v_order record;
 v_prev record;
 v_line record;
 v_item jsonb;
 v_shipment uuid;
 v_order_location uuid;
 v_qty integer;
 v_done integer;
 v_total_to_ship bigint:=0;
 v_already_dispatched integer;
 v_line_ids uuid[]:=array[]::uuid[];
 v_line_id uuid;
 v_level uuid;
 v_fulfilled boolean;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 if p_order_id is null or p_store_id is null or p_request_key is null
 or p_lines is null or pg_catalog.jsonb_typeof(p_lines)<>'array'
 or pg_catalog.jsonb_array_length(p_lines) not between 1 and 200
 or length(btrim(coalesce(p_carrier,''))) not between 2 and 120
 or length(btrim(coalesce(p_tracking,''))) not between 4 and 200 then
  raise exception 'Invalid shipment request' using errcode='22023';
 end if;
 -- Order lock serializes shipment submissions from every session.
 select * into v_order from public.orders
  where store_id=p_store_id and id=p_order_id for update;
 if not found then raise exception 'Order not found' using errcode='23503';end if;
 select * into v_prev from public.chr_shipments
  where store_id=p_store_id and order_id=p_order_id and request_key=p_request_key;
 if found then
  if v_prev.request_lines<>p_lines or v_prev.carrier<>btrim(p_carrier)
    or v_prev.tracking_reference<>btrim(p_tracking) then
   raise exception 'Shipment idempotency key reused with another request' using errcode='23514';
  end if;
  return jsonb_build_object('status','already_dispatched','shipment_id',v_prev.id,
   'order_id',p_order_id,'fulfillment_status',v_order.fulfillment_status);
 end if;
 if v_order.status<>'open' or v_order.payment_status<>'paid'
 or v_order.fulfillment_status not in ('unfulfilled','partial') then
  raise exception 'Only paid, open, non-fully-dispatched orders can be dispatched' using errcode='23514';
 end if;
 v_order_location:=(v_order.shipping_address->>'shipping_location_id')::uuid;
 if v_order_location is null then raise exception 'Order has no shipping warehouse' using errcode='23514';end if;
 insert into public.chr_shipments(store_id,order_id,request_key,request_lines,carrier,tracking_reference,actor_id)
 values(p_store_id,p_order_id,p_request_key,p_lines,btrim(p_carrier),btrim(p_tracking),auth.uid())
 returning id into v_shipment;

 for v_item in select value from pg_catalog.jsonb_array_elements(p_lines) order by value->>'order_line_id' loop
  if pg_catalog.jsonb_typeof(v_item)<>'object'
   or coalesce(v_item->>'order_line_id','') !~ '^[0-9a-fA-F-]{36}$'
   or coalesce(v_item->>'quantity','') !~ '^[0-9]{1,6}$' then
   raise exception 'Invalid shipment line' using errcode='22023';
  end if;
  v_line_id:=(v_item->>'order_line_id')::uuid;
  v_qty:=(v_item->>'quantity')::integer;
  if v_qty<1 or v_qty>100000 or v_line_id=any(v_line_ids) then
   raise exception 'Invalid or repeated order line in shipment' using errcode='22023';
  end if;
  v_line_ids:=pg_catalog.array_append(v_line_ids,v_line_id);
  select * into v_line from public.order_lines
   where store_id=p_store_id and order_id=p_order_id and id=v_line_id;
  if not found or v_line.variant_id is null then
   raise exception 'Shipment line is not part of this order' using errcode='23503';
  end if;
  select coalesce(sum(sl.quantity),0)::integer into v_already_dispatched
   from public.chr_shipment_lines sl
   join public.chr_shipments sh on sh.store_id=sl.store_id and sh.id=sl.shipment_id
   where sl.store_id=p_store_id and sh.order_id=p_order_id and sl.order_line_id=v_line_id;
  if v_qty>(v_line.quantity-v_already_dispatched) then
   raise exception 'Cannot dispatch more than unshipped order quantity' using errcode='23514';
  end if;
  update public.inventory_levels
   set on_hand=on_hand-v_qty,reserved=reserved-v_qty,updated_at=now()
   where store_id=p_store_id and variant_id=v_line.variant_id
    and location_id=v_order_location and on_hand>=v_qty and reserved>=v_qty
   returning id into v_level;
  if not found then
   raise exception 'Stock reservation and dispatch mismatch' using errcode='23514';
  end if;
  insert into public.chr_shipment_lines(store_id,shipment_id,order_line_id,quantity)
  values(p_store_id,v_shipment,v_line_id,v_qty);
  insert into public.inventory_movements(
   store_id,inventory_level_id,delta,reason,actor_user_id,idempotency_key,source_type,source_id)
  values(p_store_id,v_level,-v_qty,'fulfillment',auth.uid(),gen_random_uuid(),'shipment',v_shipment);
  v_total_to_ship:=v_total_to_ship+v_qty;
 end loop;

 -- Note: the legacy full-order fulfillment can only run on 'unfulfilled';
 -- once a partial shipment exists, this RPC owns the remaining quantities.
 select not exists (
  select 1 from public.order_lines ol
  where ol.store_id=p_store_id and ol.order_id=p_order_id
  and (select coalesce(sum(sl.quantity),0)
       from public.chr_shipment_lines sl
       join public.chr_shipments sh on sh.store_id=sl.store_id and sh.id=sl.shipment_id
       where sl.store_id=p_store_id and sl.order_line_id=ol.id and sh.order_id=p_order_id
      )<>ol.quantity
 ) into v_fulfilled;
 update public.orders
  set fulfillment_status=case when v_fulfilled then 'fulfilled' else 'partial' end,
      status=case when v_fulfilled then 'completed' else 'open' end,updated_at=now()
  where store_id=p_store_id and id=p_order_id;
 insert into public.audit_events(store_id,actor_id,actor_type,entity_type,entity_id,action,after_state)
 values(p_store_id,auth.uid(),'human','orders',p_order_id,'partial_dispatch',
  jsonb_build_object('shipment_id',v_shipment,'carrier',btrim(p_carrier),
   'tracking',btrim(p_tracking),'total_dispatched_units',v_total_to_ship,
   'fully_dispatched',v_fulfilled));
 return jsonb_build_object('status','dispatched','shipment_id',v_shipment,
  'order_id',p_order_id,'quantity',v_total_to_ship,
  'fulfillment_status',case when v_fulfilled then 'fulfilled' else 'partial' end);
end $dispatch$;
revoke all on function public.chr_dispatch_order_lines(uuid,uuid,jsonb,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.chr_dispatch_order_lines(uuid,uuid,jsonb,text,text,uuid)
 to authenticated;
