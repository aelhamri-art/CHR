-- CHR: first persisted rate-eligibility engine for configured shipping zones and rates.
-- This computes candidate tariffs only, NOT a carrier quote, final tax, or multi-profile checkout total.
create or replace function public.eligible_shipping_rates(
  p_store_id uuid, p_profile_id uuid, p_country text,
  p_postal_code text, p_weight_grams integer, p_subtotal_minor bigint
)
returns table (
  rate_id uuid, zone_id uuid, rate_name text,
  mode text, amount_minor bigint
)
language sql stable security invoker set search_path = ''
as $$
 select r.id,r.zone_id,r.name,r.mode,r.amount_minor
 from public.shipping_rates r
 join public.shipping_zones z on (z.id=r.zone_id and z.store_id=r.store_id)
 join public.shipping_profiles p on (p.id=z.profile_id and p.store_id=z.store_id)
 where app_private.can_read_store(p_store_id)
   and r.store_id=p_store_id
   and p.id=p_profile_id
   and r.enabled=true
   and r.mode <> 'carrier'
   and p_country is not null and length(p_country)=2
   and upper(p_country)=any(z.countries)
   and (cardinality(z.postal_prefixes)=0 or exists (
        select 1 from unnest(z.postal_prefixes) pref
        where starts_with(upper(coalesce(p_postal_code,'')),upper(pref))))
   and not exists (select 1 from unnest(z.excluded_postal_prefixes) pref
        where starts_with(upper(coalesce(p_postal_code,'')),upper(pref)))
   and p_weight_grams is not null and p_weight_grams >= 0
   and p_subtotal_minor is not null and p_subtotal_minor >= 0
   and (r.min_weight_grams is null or p_weight_grams>=r.min_weight_grams)
   and (r.max_weight_grams is null or p_weight_grams<=r.max_weight_grams)
   and (r.min_order_minor is null or p_subtotal_minor>=r.min_order_minor)
   and (r.max_order_minor is null or p_subtotal_minor<=r.max_order_minor)
 order by r.amount_minor, r.name;
$$;
revoke all on function public.eligible_shipping_rates(uuid,uuid,text,text,integer,bigint) from public, anon;
grant execute on function public.eligible_shipping_rates(uuid,uuid,text,text,integer,bigint) to authenticated;
