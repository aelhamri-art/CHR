-- CHR storefront: staff preview without publishing and verified legal publication gate.
alter table public.storefront_settings
 add column legal_notice text,
 add column privacy_policy text,
 add column terms_of_sale text,
 add column published_at timestamptz;
create policy storefront_catalog_staff_preview on public.storefront_catalog
 for select to authenticated using(app_private.can_read_store(store_id));
alter table public.storefront_settings
 add constraint storefront_published_requires_documents check(
  not published or (
   contact_email is not null and length(trim(contact_email))>5 and
   legal_notice is not null and length(trim(legal_notice))>=100 and
   privacy_policy is not null and length(trim(privacy_policy))>=100 and
   terms_of_sale is not null and length(trim(terms_of_sale))>=100
  ));
create or replace function app_private.guard_storefront_publish()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if new.published=true and (tg_op='INSERT' or old.published=false) then
  if not exists (select 1 from public.storefront_catalog c
    where c.store_id=new.store_id and c.image_path is not null)
  then raise exception 'Publication requires at least one active product with approved image' using errcode='23514';end if;
  new.published_at:=now();
 end if;
 if new.published=false then new.published_at:=null;end if;
 return new;
end $$;
revoke all on function app_private.guard_storefront_publish() from public,anon,authenticated;
create trigger trg_storefront_publish_guard before insert or update on public.storefront_settings
for each row execute function app_private.guard_storefront_publish();
