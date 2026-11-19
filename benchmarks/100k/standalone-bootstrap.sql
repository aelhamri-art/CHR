-- TEST ENVIRONMENT ONLY. Runs exclusively inside GitHub Actions Postgres:17.
-- This is a minimal compatibility bootstrap for Supabase-managed roles and schemas.
-- Do not deploy this file to Supabase, production or a customer database.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema if not exists auth;
create schema if not exists storage;
create schema if not exists extensions;
grant usage on schema auth to anon, authenticated;
grant usage on schema storage to authenticated;
create table auth.users(
 id uuid primary key,
 email text unique,
 created_at timestamptz not null default now()
);
create or replace function auth.uid() returns uuid
language sql stable set search_path=''
as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant execute on function auth.uid() to anon,authenticated;

create table storage.buckets(
 id text primary key,
 name text not null unique,
 public boolean not null default false,
 file_size_limit bigint,
 allowed_mime_types text[]
);
create table storage.objects(
 id uuid primary key default gen_random_uuid(),
 bucket_id text not null references storage.buckets(id),
 name text not null,
 owner uuid,
 metadata jsonb not null default '{}'::jsonb,
 unique(bucket_id,name)
);
alter table storage.objects enable row level security;
grant select,insert,update,delete on storage.objects to authenticated;
create or replace function storage.foldername(path text)
returns text[] language sql immutable set search_path=''
as $$ select array[split_part(path,'/',1)] || 
  case when strpos(path,'/')>0 then
   string_to_array(substring(path from position('/' in path)+1),'/')
  else array[]::text[] end
$$;
grant execute on function storage.foldername(text) to authenticated;

-- Match PostgreSQL 17 + pg_trgm search operators; no SQL migrations are mocked.
create extension if not exists pg_trgm with schema extensions;
