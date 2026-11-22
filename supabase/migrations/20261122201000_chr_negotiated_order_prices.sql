CREATE OR REPLACE FUNCTION public.create_order(p_store_id uuid, p_customer_id uuid, p_location_id uuid, p_shipping_profile_id uuid, p_country text, p_postal text, p_lines jsonb, p_idempotency_key uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
 v_id uuid;
 v_existing uuid;
 v_no bigint;
 v_item jsonb;
 v_variant_id uuid;
 v_variant record;
 v_level record;
 v_qty integer;
 v_weight bigint:=0;
 v_subtotal bigint:=0;
 v_shipping bigint;
 v_tax bigint;
 v_tax_rate int;
 v_tax_shipping boolean;
 v_total bigint;
 v_order_lines jsonb:='[]'::jsonb;
 v_seen uuid[]:=array[]::uuid[];
 v_ship_name text;
 v_agreements jsonb:='[]'::jsonb;
 v_agreement jsonb;
 v_base_unit bigint;
 v_agreed_unit bigint;
 v_reason text;
 v_limit_bps integer;
 v_price_override_enabled boolean;
 v_order_line_limit integer;
 v_country text:=upper(coalesce(p_country,''));
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 select coalesce((select p.order_line_limit from public.chr_business_policies p where p.store_id=p_store_id),250)
 into v_order_line_limit;
 if p_idempotency_key is null or p_store_id is null or p_customer_id is null or p_location_id is null
  or p_shipping_profile_id is null or p_postal is null or p_country is null
  or v_country !~ '^[A-Z]{2}$'
  or p_lines is null or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines) not between 1 and v_order_line_limit then
  raise exception 'Invalid order request' using errcode='22023';
 end if;
 if not exists (select 1 from public.customers where store_id=p_store_id and id=p_customer_id)
 or not exists (select 1 from public.locations where store_id=p_store_id and id=p_location_id and active)
 or not exists (select 1 from public.shipping_profiles where store_id=p_store_id and id=p_shipping_profile_id) then
  raise exception 'Customer, location or shipping profile invalid' using errcode='23503';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(p_store_id::text||':'||p_idempotency_key::text,0));
 select order_id into v_existing from public.order_requests
 where store_id=p_store_id and idempotency_key=p_idempotency_key;
 if found then return jsonb_build_object('status','already_created','order_id',v_existing);end if;

 for v_item in select value from jsonb_array_elements(p_lines) order by value->>'variant_id' loop
  if jsonb_typeof(v_item)<>'object'
    or coalesce(v_item->>'variant_id','') !~ '^[0-9a-fA-F-]{36}$'
    or coalesce(v_item->>'quantity','') !~ '^[0-9]+$' then
    raise exception 'Malformed order line' using errcode='22023';
  end if;
  v_variant_id := (v_item->>'variant_id')::uuid;
  v_qty := (v_item->>'quantity')::int;
  if v_qty < 1 or v_qty > 100000 or v_variant_id=any(v_seen) then
   raise exception 'Invalid or duplicate variant quantity' using errcode='22023';
  end if;
  v_seen:=array_append(v_seen,v_variant_id);
  select v.id,v.title,v.sku,v.price_minor,v.weight_grams,v.taxable,p.title as product_title
  into v_variant from public.product_variants v
  join public.products p on p.store_id=v.store_id and p.id=v.product_id
  where v.store_id=p_store_id and v.id=v_variant_id and p.status='active'
  for share of v;
  if not found then raise exception 'Unknown or inactive variant' using errcode='23503';end if;
  v_base_unit:=v_variant.price_minor;
  v_agreed_unit:=v_base_unit;
  v_reason:=nullif(btrim(coalesce(v_item->>'price_reason','')),'');
  if v_item ? 'unit_price_minor' and (v_item->>'unit_price_minor') is distinct from v_base_unit::text then
   if jsonb_typeof(v_item->'unit_price_minor') not in ('number','string')
    or coalesce(v_item->>'unit_price_minor','') !~ '^[0-9]{1,11}$' then
    raise exception 'Agreed unit price must be a nonnegative integer in minor units' using errcode='22023';
   end if;
   v_agreed_unit:=(v_item->>'unit_price_minor')::bigint;
   select coalesce((select p.allow_negotiated_prices from public.chr_business_policies p where p.store_id=p_store_id),true),
          coalesce((select p.max_price_reduction_bps from public.chr_business_policies p where p.store_id=p_store_id),4000)
    into v_price_override_enabled,v_limit_bps;
   if not v_price_override_enabled then
    raise exception 'Negotiated prices disabled for this store' using errcode='23514';
   end if;
   if v_reason is null or length(v_reason) not between 8 and 500 then
    raise exception 'Explicit price justification (8 to 500 characters) required' using errcode='22023';
   end if;
   if v_agreed_unit < v_base_unit and v_base_unit>0 and
      (v_base_unit-v_agreed_unit)::numeric*10000 > v_base_unit::numeric*v_limit_bps then
    raise exception 'Negotiated price exceeds the authorized reduction' using errcode='23514';
   end if;
   v_agreements:=v_agreements||jsonb_build_array(jsonb_build_object(
    'variant_id',v_variant_id,'base_unit_minor',v_base_unit,
    'agreed_unit_minor',v_agreed_unit,'quantity',v_qty,'reason',v_reason));
  end if;
  select id,on_hand,reserved into v_level from public.inventory_levels
  where store_id=p_store_id and variant_id=v_variant_id and location_id=p_location_id
  for update;
  if not found or (v_level.on_hand-v_level.reserved)<v_qty then
   raise exception 'Insufficient available inventory for variant %',v_variant_id using errcode='23514';
  end if;
  update public.inventory_levels set reserved=reserved+v_qty,updated_at=now() where id=v_level.id;
  v_subtotal:=v_subtotal+(v_agreed_unit*v_qty);
  v_weight:=v_weight+(v_variant.weight_grams::bigint*v_qty);
  v_order_lines:=v_order_lines||jsonb_build_array(jsonb_build_object(
   'variant_id',v_variant_id,'product_title',v_variant.product_title,'variant_title',v_variant.title,
   'sku',v_variant.sku,'quantity',v_qty,'unit_price_minor',v_agreed_unit,'taxable',v_variant.taxable
  ));
 end loop;
 if v_weight>2147483647 then raise exception 'Excessive shipping weight' using errcode='22023';end if;
 select r.amount_minor,r.rate_name into v_shipping,v_ship_name from
  public.eligible_shipping_rates(p_store_id,p_shipping_profile_id,v_country,p_postal,v_weight::int,v_subtotal) r limit 1;
 if not found then raise exception 'No eligible shipping rate' using errcode='23514';end if;
 select rate_basis_points,tax_shipping into v_tax_rate,v_tax_shipping
 from public.tax_rules where store_id=p_store_id and country=v_country and active=true
 order by rate_basis_points desc limit 1;
 if not found then raise exception 'Country tax rule must be configured before placing orders' using errcode='23514'; end if;
 select coalesce(sum(case when (t.v_line_json->>'taxable')::boolean
 then round((t.v_line_json->>'unit_price_minor')::numeric*(t.v_line_json->>'quantity')::int*v_tax_rate/10000)::bigint
 else 0 end),0)
 into v_tax from jsonb_array_elements(v_order_lines) as t(v_line_json);
 if v_tax_shipping then
  v_tax:=v_tax+round(v_shipping::numeric*v_tax_rate/10000)::bigint;
 end if;
 v_total:=v_subtotal+v_shipping+v_tax;
 insert into public.order_counters(store_id,last_order_no) values(p_store_id,1000)
 on conflict (store_id) do update set last_order_no=public.order_counters.last_order_no+1
 returning last_order_no into v_no;
 insert into public.orders(store_id,order_number,customer_id,currency,status,payment_status,fulfillment_status,
 subtotal_minor,shipping_minor,tax_minor,total_minor,shipping_address,placed_at)
 values(p_store_id,v_no::text,p_customer_id,'EUR','open','pending','unfulfilled',
 v_subtotal,v_shipping,v_tax,v_total,jsonb_build_object('country',v_country,'postal',p_postal,
 'shipping_profile_id',p_shipping_profile_id,'shipping_rate_name',v_ship_name,'shipping_location_id',p_location_id),now())
 returning id into v_id;
 for v_item in select value from jsonb_array_elements(v_order_lines) loop
  insert into public.order_lines(store_id,order_id,variant_id,product_title,variant_title,sku,
    quantity,unit_price_minor,tax_minor,discount_minor)
  values(p_store_id,v_id,(v_item->>'variant_id')::uuid,v_item->>'product_title',
   v_item->>'variant_title',v_item->>'sku',(v_item->>'quantity')::int,
   (v_item->>'unit_price_minor')::bigint,
   case when (v_item->>'taxable')::boolean then round(((v_item->>'unit_price_minor')::numeric*(v_item->>'quantity')::int)*v_tax_rate/10000)::bigint else 0 end,0);
 end loop;
 for v_agreement in select value from jsonb_array_elements(v_agreements) loop
  insert into public.chr_order_price_agreements(
   store_id,order_id,variant_id,base_unit_minor,agreed_unit_minor,
   quantity,reason,approved_by)
  values(p_store_id,v_id,(v_agreement->>'variant_id')::uuid,
   (v_agreement->>'base_unit_minor')::bigint,
   (v_agreement->>'agreed_unit_minor')::bigint,
   (v_agreement->>'quantity')::integer,v_agreement->>'reason',auth.uid());
 end loop;
 insert into public.order_requests(store_id,idempotency_key,order_id)values(p_store_id,p_idempotency_key,v_id);
 insert into public.audit_events(store_id,actor_id,actor_type,entity_type,entity_id,action,after_state)
 values(p_store_id,auth.uid(),'human','orders',v_id,'create',
  jsonb_build_object('total_minor',v_total,'shipping_minor',v_shipping,'tax_minor',v_tax,'lines',jsonb_array_length(v_order_lines),'negotiated_lines',jsonb_array_length(v_agreements)));
 return jsonb_build_object('status','created','order_id',v_id,'order_number',v_no,'total_minor',v_total,'currency','EUR');
end $function$
;
