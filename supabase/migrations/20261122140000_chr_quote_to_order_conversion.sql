-- AXIUM OS CHR / P0: accepted quote -> real order, transactional and idempotent.
-- An accepted quote cannot silently create duplicate orders, and price/stock/tax
-- validations remain inside the existing, tested create_order RPC.
create table if not exists public.chr_quote_conversions(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 quote_id uuid not null,
 order_id uuid not null,
 quote_revision integer not null check(quote_revision>=1),
 actor_id uuid not null,
 created_at timestamptz not null default now(),
 unique(store_id,quote_id),
 unique(store_id,order_id),
 foreign key(store_id,quote_id) references public.chr_sales_quotes(store_id,id) on delete restrict,
 foreign key(store_id,order_id) references public.orders(store_id,id) on delete restrict
);
create index if not exists idx_chr_quote_conversions_order on public.chr_quote_conversions(store_id,order_id);
alter table public.chr_quote_conversions enable row level security;
revoke all on public.chr_quote_conversions from public,anon,authenticated;
grant select on public.chr_quote_conversions to authenticated;
create policy chr_quote_conversions_read on public.chr_quote_conversions
 for select to authenticated using(app_private.can_read_store(store_id));

create or replace function public.chr_convert_accepted_quote_to_order(
 p_store_id uuid,
 p_quote_id uuid,
 p_expected_revision integer,
 p_customer_id uuid,
 p_location_id uuid,
 p_shipping_profile_id uuid,
 p_country text,
 p_postal text,
 p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path=''
as $convert$
declare
 q record;
 existing record;
 line jsonb;
 order_lines jsonb:='[]'::jsonb;
 response jsonb;
 order_id uuid;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 if p_quote_id is null or p_expected_revision is null or p_customer_id is null
  or p_location_id is null or p_shipping_profile_id is null or p_idempotency_key is null then
  raise exception 'Missing quote, version, customer, location, profile or idempotency key' using errcode='22023';
 end if;
 select * into q from public.chr_sales_quotes
 where store_id=p_store_id and id=p_quote_id for update;
 if not found then raise exception 'Quote not found' using errcode='23503';end if;
 select order_id,quote_revision into existing from public.chr_quote_conversions
  where store_id=p_store_id and quote_id=p_quote_id;
 if found then
  return jsonb_build_object('status','already_converted','quote_id',p_quote_id,'order_id',existing.order_id,'quote_revision',existing.quote_revision);
 end if;
 if q.status<>'accepted' then
  raise exception 'Only an explicitly accepted quote can be converted' using errcode='23514';
 end if;
 if q.revision<>p_expected_revision then
  raise exception 'Quote changed since review; reload before conversion' using errcode='40001';
 end if;
 if q.customer_id is not null and q.customer_id<>p_customer_id then
  raise exception 'Customer mismatch with accepted quote' using errcode='23514';
 end if;
 if not exists (select 1 from public.customers
   where store_id=p_store_id and id=p_customer_id) then
  raise exception 'Customer does not belong to this store' using errcode='23503';
 end if;
 for line in select value from pg_catalog.jsonb_array_elements(q.lines) loop
  order_lines:=order_lines||jsonb_build_array(jsonb_build_object(
   'variant_id',line->>'variant_id',
   'quantity',line->>'quantity',
   'unit_price_minor',line->>'unit_price_minor',
   'price_reason',coalesce(nullif(line->>'price_reason',''),
     'Tarif contractuel du devis accepté, révision '||q.revision::text)
  ));
 end loop;
 -- create_order independently checks tenant, price policy, VAT, eligible freight
 -- and exact currently available stock. A shortage aborts atomically.
 response:=public.create_order(
  p_store_id,p_customer_id,p_location_id,p_shipping_profile_id,
  p_country,p_postal,order_lines,p_idempotency_key
 );
 order_id:=(response->>'order_id')::uuid;
 if order_id is null then raise exception 'Order conversion returned no order ID';end if;
 insert into public.chr_quote_conversions(store_id,quote_id,order_id,quote_revision,actor_id)
 values(p_store_id,p_quote_id,order_id,q.revision,auth.uid());
 insert into public.chr_sales_quote_events(
  store_id,quote_id,event_type,from_status,to_status,reason,revision,actor_id)
 values(p_store_id,p_quote_id,'converted',q.status,q.status,
   'Commande créée après confirmation client, devis accepté et revalidation stock/prix',q.revision,auth.uid());
 return jsonb_build_object(
  'status','converted','quote_id',p_quote_id,'quote_revision',q.revision,
  'order_id',order_id,'order_number',response->>'order_number',
  'total_minor',response->'total_minor'
 );
end $convert$;
revoke all on function public.chr_convert_accepted_quote_to_order(uuid,uuid,integer,uuid,uuid,uuid,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.chr_convert_accepted_quote_to_order(uuid,uuid,integer,uuid,uuid,uuid,text,text,uuid)
 to authenticated;
