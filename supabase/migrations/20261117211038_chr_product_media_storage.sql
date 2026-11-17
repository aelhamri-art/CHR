-- CHR : product media metadata and tenant-scoped object uploads.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('chr-product-media','chr-product-media',true,5242880,array['image/jpeg','image/png','image/webp','image/avif'])
on conflict(id) do nothing;

create table if not exists public.product_media(
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null,
 product_id uuid not null,
 storage_path text not null,
 alt_text text,
 position integer not null default 0 check(position>=0),
 created_at timestamptz not null default now(),
 unique(store_id,storage_path),
 foreign key(store_id,product_id) references public.products(store_id,id) on delete restrict,
 check(split_part(storage_path,'/',1)=store_id::text),
 check(split_part(storage_path,'/',2)=product_id::text)
);
alter table public.product_media enable row level security;
create policy product_media_select on public.product_media for select to authenticated
using(app_private.can_read_store(store_id));
create policy product_media_insert on public.product_media for insert to authenticated
with check(app_private.can_manage_store(store_id));
create policy product_media_update on public.product_media for update to authenticated
using(app_private.can_manage_store(store_id)) with check(app_private.can_manage_store(store_id));
create policy product_media_delete on public.product_media for delete to authenticated
using(app_private.can_manage_store(store_id));
revoke all on public.product_media from anon,authenticated;
grant select,insert,update,delete on public.product_media to authenticated;
create index if not exists idx_product_media_product on public.product_media(store_id,product_id,position);
create trigger trg_product_media_tenant_lock before update on public.product_media for each row execute function app_private.forbid_tenant_change();
create trigger trg_product_media_audit after insert or update or delete on public.product_media for each row execute function app_private.audit_mutation();

create policy chr_product_media_insert on storage.objects
for insert to authenticated
with check(bucket_id='chr-product-media' and
  (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$' and
  app_private.can_manage_store(((storage.foldername(name))[1])::uuid));
create policy chr_product_media_delete on storage.objects
for delete to authenticated
using(bucket_id='chr-product-media' and
  (storage.foldername(name))[1] ~ '^[0-9a-f-]{36}$' and
  app_private.can_manage_store(((storage.foldername(name))[1])::uuid));
