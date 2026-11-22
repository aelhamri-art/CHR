-- AXIUM OS CHR / P0: internal versioned commercial quotes.
-- Public storefront quote snapshots are intentionally not modified.
-- Workflow: draft -> proposed -> accepted/declined; an accepted proposal
-- can be explicitly reopened, creating a NEW version of its priced terms.
create table if not exists public.chr_sales_quotes (
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.stores(id) on delete cascade,
 customer_id uuid,
 request_key uuid not null,
 company_name text,
 contact_email text,
 notes text,
 status text not null default 'draft'
   check(status in ('draft','proposed','accepted','declined','cancelled')),
 revision integer not null default 1 check(revision>=1),
 lines jsonb not null check(jsonb_typeof(lines)='array'),
 subtotal_minor bigint not null check(subtotal_minor>=0),
 created_by uuid not null,
 updated_by uuid not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(store_id,id),
 unique(store_id,created_by,request_key),
 foreign key(store_id,customer_id) references public.customers(store_id,id)
);
create index if not exists idx_chr_quotes_store_status
 on public.chr_sales_quotes(store_id,status,updated_at desc);
alter table public.chr_sales_quotes enable row level security;
revoke all on public.chr_sales_quotes from public,anon,authenticated;
grant select on public.chr_sales_quotes to authenticated;
create policy chr_sales_quote_read on public.chr_sales_quotes
 for select to authenticated using(app_private.can_read_store(store_id));

create table if not exists public.chr_sales_quote_revisions (
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 quote_id uuid not null,
 revision integer not null check(revision>=1),
 line_snapshot jsonb not null check(jsonb_typeof(line_snapshot)='array'),
 subtotal_minor bigint not null check(subtotal_minor>=0),
 company_name text,
 contact_email text,
 notes text,
 actor_id uuid not null,
 created_at timestamptz not null default now(),
 unique(store_id,quote_id,revision),
 foreign key(store_id,quote_id) references public.chr_sales_quotes(store_id,id) on delete restrict
);
alter table public.chr_sales_quote_revisions enable row level security;
revoke all on public.chr_sales_quote_revisions from public,anon,authenticated;
grant select on public.chr_sales_quote_revisions to authenticated;
create policy chr_sales_quote_revision_read on public.chr_sales_quote_revisions
 for select to authenticated using(app_private.can_read_store(store_id));

create table if not exists public.chr_sales_quote_events (
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 quote_id uuid not null,
 event_type text not null check(length(event_type) between 2 and 64),
 from_status text,
 to_status text,
 reason text,
 revision integer not null,
 actor_id uuid not null,
 created_at timestamptz not null default now(),
 foreign key(store_id,quote_id) references public.chr_sales_quotes(store_id,id) on delete restrict
);
create index if not exists idx_chr_quote_events_timeline
 on public.chr_sales_quote_events(store_id,quote_id,created_at);
alter table public.chr_sales_quote_events enable row level security;
revoke all on public.chr_sales_quote_events from public,anon,authenticated;
grant select on public.chr_sales_quote_events to authenticated;
create policy chr_sales_quote_event_read on public.chr_sales_quote_events
 for select to authenticated using(app_private.can_read_store(store_id));

create or replace function public.chr_save_sales_quote(
 p_store_id uuid,
 p_lines jsonb,
 p_quote_id uuid default null,
 p_expected_revision integer default null,
 p_customer_id uuid default null,
 p_company_name text default null,
 p_contact_email text default null,
 p_notes text default null,
 p_reopen boolean default false,
 p_request_key uuid default null
) returns jsonb language plpgsql security definer set search_path=''
as $quote$
declare
 v_quote record;
 v_item jsonb;
 v_product record;
 v_store_policy record;
 v_variant_id uuid;
 v_seen uuid[]:=array[]::uuid[];
 v_quantity integer;
 v_unit_minor bigint;
 v_price_reason text;
 v_available integer;
 v_shortage integer;
 v_subtotal numeric:=0;
 v_lines jsonb:='[]'::jsonb;
 v_id uuid;
 v_revision integer;
 v_status text;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 select
  coalesce(p.allow_negotiated_prices,true) as allow_prices,
  coalesce(p.max_price_reduction_bps,4000) as max_reduction,
  coalesce(p.quote_line_limit,250) as max_lines,
  coalesce(p.allow_backorder_quotes,true) as allow_shortage
 into v_store_policy
 from (select 1) base left join public.chr_business_policies p on p.store_id=p_store_id;
 if p_store_id is null or p_lines is null or jsonb_typeof(p_lines)<>'array'
  or jsonb_array_length(p_lines)<1 or jsonb_array_length(p_lines)>v_store_policy.max_lines
  or length(coalesce(p_company_name,''))>180
  or length(coalesce(p_contact_email,''))>254
  or length(coalesce(p_notes,''))>5000 then
  raise exception 'Invalid quote: check line count, company, email and notes' using errcode='22023';
 end if;
 if p_customer_id is not null and not exists (
  select 1 from public.customers c where c.store_id=p_store_id and c.id=p_customer_id
 ) then
  raise exception 'Customer does not belong to this store' using errcode='23503';
 end if;
 if p_quote_id is null then
  if p_request_key is null then
   raise exception 'Idempotency key required for new quote' using errcode='22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chr:internal-quote:'||p_store_id::text||':'||auth.uid()::text||':'||p_request_key::text,7));
  select q.id,q.revision into v_id,v_revision
    from public.chr_sales_quotes q
   where q.store_id=p_store_id and q.created_by=auth.uid() and q.request_key=p_request_key;
  if found then
   return jsonb_build_object('quote_id',v_id,'revision',v_revision,'status','already_created');
  end if;
 else
  if p_expected_revision is null then
   raise exception 'Expected revision required to edit a quote' using errcode='22023';
  end if;
  select * into v_quote from public.chr_sales_quotes q
    where q.store_id=p_store_id and q.id=p_quote_id for update;
  if not found then raise exception 'Quote not found' using errcode='23503';end if;
  if v_quote.revision<>p_expected_revision then
   raise exception 'Quote changed since it was opened; reload before editing' using errcode='40001';
  end if;
  if v_quote.status='accepted' and not coalesce(p_reopen,false) then
   raise exception 'Accepted quote requires explicit reopen for new revision' using errcode='23514';
  end if;
 end if;

 -- Quote lines are not stock reservations; a shortage is recorded explicitly.
 -- Never trust a browser-supplied title, catalog price, quantity type or tenant ID.
 for v_item in select value from pg_catalog.jsonb_array_elements(p_lines)
   order by value->>'variant_id' loop
  if jsonb_typeof(v_item)<>'object'
   or coalesce(v_item->>'variant_id','') !~ '^[a-fA-F0-9-]{36}$'
   or coalesce(v_item->>'quantity','') !~ '^[0-9]{1,6}$' then
   raise exception 'Malformed quote line' using errcode='22023';
  end if;
  v_variant_id:=(v_item->>'variant_id')::uuid;
  v_quantity:=(v_item->>'quantity')::integer;
  if v_quantity<1 or v_quantity>100000 or v_variant_id=any(v_seen) then
   raise exception 'Invalid or duplicate quote variant' using errcode='22023';
  end if;
  v_seen:=pg_catalog.array_append(v_seen,v_variant_id);
  select p.title as product_title,v.title as variant_title,v.sku,
         v.price_minor,v.taxable,v.weight_grams
    into v_product from public.product_variants v
    join public.products p on p.store_id=v.store_id and p.id=v.product_id
   where v.store_id=p_store_id and v.id=v_variant_id and p.status='active';
  if not found then
   raise exception 'Unknown or inactive quote variant' using errcode='23503';
  end if;
  v_unit_minor:=v_product.price_minor;
  v_price_reason:=nullif(btrim(coalesce(v_item->>'price_reason','')),'');
  if v_item ? 'unit_price_minor' and (v_item->>'unit_price_minor') is distinct from v_unit_minor::text then
   if jsonb_typeof(v_item->'unit_price_minor') not in ('number','string')
    or coalesce(v_item->>'unit_price_minor','') !~ '^[0-9]{1,11}$' then
    raise exception 'Invalid negotiated unit price' using errcode='22023';
   end if;
   v_unit_minor:=(v_item->>'unit_price_minor')::bigint;
   if not v_store_policy.allow_prices then
    raise exception 'Negotiated prices disabled by store policy' using errcode='23514';
   end if;
   if v_price_reason is null or length(v_price_reason) not between 8 and 500 then
    raise exception 'Price adjustment needs an explicit justification' using errcode='22023';
   end if;
   if v_product.price_minor>0 and v_unit_minor<v_product.price_minor and
    (v_product.price_minor-v_unit_minor)::numeric*10000 >
      v_product.price_minor::numeric*v_store_policy.max_reduction then
    raise exception 'Quote price exceeds authorized reduction' using errcode='23514';
   end if;
  end if;
  select coalesce(sum(greatest(l.on_hand-l.reserved,0)),0)::integer
    into v_available from public.inventory_levels l
   join public.locations loc on loc.store_id=l.store_id and loc.id=l.location_id
   where l.store_id=p_store_id and l.variant_id=v_variant_id and loc.active;
  v_shortage:=greatest(v_quantity-v_available,0);
  if v_shortage>0 and not v_store_policy.allow_shortage then
   raise exception 'Backorder quote disabled; quantity exceeds physical availability' using errcode='23514';
  end if;
  v_subtotal:=v_subtotal+v_quantity::numeric*v_unit_minor;
  if v_subtotal>9223372036854775807 then
   raise exception 'Quote amount exceeds supported monetary range' using errcode='22023';
  end if;
  v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
   'variant_id',v_variant_id,'product_title',v_product.product_title,
   'variant_title',v_product.variant_title,'sku',v_product.sku,
   'quantity',v_quantity,'list_unit_minor',v_product.price_minor,
   'unit_price_minor',v_unit_minor,'price_reason',v_price_reason,
   'available_at_revision',v_available,'backorder_at_revision',v_shortage,
   'taxable',v_product.taxable));
 end loop;
 if p_quote_id is null then
  insert into public.chr_sales_quotes(
   store_id,customer_id,request_key,company_name,contact_email,notes,status,
   revision,lines,subtotal_minor,created_by,updated_by)
  values(p_store_id,p_customer_id,p_request_key,
   nullif(btrim(coalesce(p_company_name,'')),''),
   nullif(btrim(coalesce(p_contact_email,'')),''),p_notes,'draft',1,
   v_lines,v_subtotal::bigint,auth.uid(),auth.uid())
  returning id,revision into v_id,v_revision;
  v_status:='draft';
 else
  v_id:=p_quote_id;
  v_revision:=v_quote.revision+1;
  v_status:='draft';
  update public.chr_sales_quotes set
   customer_id=p_customer_id,
   company_name=nullif(btrim(coalesce(p_company_name,'')),''),
   contact_email=nullif(btrim(coalesce(p_contact_email,'')),''),
   notes=p_notes,lines=v_lines,subtotal_minor=v_subtotal::bigint,
   revision=v_revision,status='draft',
   updated_by=auth.uid(),updated_at=now()
  where id=v_id and store_id=p_store_id;
 end if;
 insert into public.chr_sales_quote_revisions(
  store_id,quote_id,revision,line_snapshot,subtotal_minor,
  company_name,contact_email,notes,actor_id)
 values(p_store_id,v_id,v_revision,v_lines,v_subtotal::bigint,
  nullif(btrim(coalesce(p_company_name,'')),''),
  nullif(btrim(coalesce(p_contact_email,'')),''),p_notes,auth.uid());
 insert into public.chr_sales_quote_events(
  store_id,quote_id,event_type,from_status,to_status,revision,actor_id)
 values(p_store_id,v_id,
  case when p_quote_id is null then 'created' else 'revised' end,
  case when p_quote_id is null then null else v_quote.status end,
  'draft',v_revision,auth.uid());
 return jsonb_build_object('quote_id',v_id,'revision',v_revision,
  'status',v_status,'subtotal_minor',v_subtotal::bigint,
  'has_backorder',exists(select 1 from jsonb_array_elements(v_lines) z
       where (z->>'backorder_at_revision')::integer>0));
end $quote$;

create or replace function public.chr_set_sales_quote_status(
 p_store_id uuid,p_quote_id uuid,p_expected_revision integer,p_new_status text,
 p_reason text default null
) returns jsonb language plpgsql security definer set search_path=''
as $transition$
declare q record;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 if p_reason is not null and length(p_reason)>500 then
  raise exception 'Reason too long' using errcode='22023';
 end if;
 select * into q from public.chr_sales_quotes
  where store_id=p_store_id and id=p_quote_id for update;
 if not found then raise exception 'Quote not found' using errcode='23503';end if;
 if q.revision is distinct from p_expected_revision then
  raise exception 'Quote changed; reload before changing status' using errcode='40001';
 end if;
 if not (
  (q.status='draft' and p_new_status in ('proposed','cancelled'))
  or (q.status='proposed' and p_new_status in ('accepted','declined','cancelled'))
  or (q.status='declined' and p_new_status in ('draft','cancelled'))
  or (q.status='cancelled' and p_new_status='draft')
  or (q.status='accepted' and p_new_status='draft')
 ) then
  raise exception 'Invalid quote transition; use an explicit revision to change accepted terms' using errcode='23514';
 end if;
 update public.chr_sales_quotes set status=p_new_status,updated_at=now(),updated_by=auth.uid()
 where id=p_quote_id and store_id=p_store_id;
 insert into public.chr_sales_quote_events(
  store_id,quote_id,event_type,from_status,to_status,reason,revision,actor_id)
 values(p_store_id,p_quote_id,'status_changed',q.status,p_new_status,p_reason,q.revision,auth.uid());
 return jsonb_build_object('quote_id',p_quote_id,'revision',q.revision,'status',p_new_status);
end $transition$;

revoke all on function public.chr_save_sales_quote(uuid,jsonb,uuid,integer,uuid,text,text,text,boolean,uuid)
 from public,anon,authenticated;
grant execute on function public.chr_save_sales_quote(uuid,jsonb,uuid,integer,uuid,text,text,text,boolean,uuid)
 to authenticated;
revoke all on function public.chr_set_sales_quote_status(uuid,uuid,integer,text,text)
 from public,anon,authenticated;
grant execute on function public.chr_set_sales_quote_status(uuid,uuid,integer,text,text)
 to authenticated;
