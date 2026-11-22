-- No storefront can become public with missing legal/customer-contact details.
-- This guard is a minimum presence check, not a legal approval certificate.
create or replace function app_private.guard_storefront_publish()
returns trigger language plpgsql security definer set search_path=''
as $pub$
begin
 if new.published then
  if coalesce(btrim(new.contact_email),'') !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
   raise exception 'Publication requires a valid official contact email' using errcode='23514';
  end if;
  if length(btrim(coalesce(new.legal_notice,'')))<80
    or length(btrim(coalesce(new.privacy_policy,'')))<80
    or length(btrim(coalesce(new.terms_of_sale,'')))<80 then
   raise exception 'Publication requires legal notices, privacy policy and terms of sale to be completed and approved' using errcode='23514';
  end if;
  if not exists(
   select 1 from public.storefront_catalog c
   where c.store_id=new.store_id and c.image_path is not null
  ) then
   raise exception 'Publication requires an active product with approved media' using errcode='23514';
  end if;
  if tg_op='INSERT' or old.published=false then new.published_at:=now();end if;
 else new.published_at:=null;
 end if;
 return new;
end $pub$;
