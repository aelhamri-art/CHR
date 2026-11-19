-- CHR isolated PostgreSQL 17: 100,000 realistic SKU fixtures + second tenant.
-- DO NOT RUN ON PRODUCTION. This file is for a disposable CI PostgreSQL service only.
set statement_timeout='10min';
insert into auth.users(id,email) values
 ('11000000-0000-4000-8000-000000000001','owner-a@staging.invalid'),
 ('22000000-0000-4000-8000-000000000002','owner-b@staging.invalid');
insert into public.stores(id,owner_user_id,slug,name) values
 ('a1000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001','chr-scale-a','CHR STAGING TENANT A'),
 ('b2000000-0000-4000-8000-000000000002','22000000-0000-4000-8000-000000000002','chr-scale-b','CHR STAGING TENANT B');
insert into public.storefront_settings(store_id,public_slug,brand_name) values
 ('a1000000-0000-4000-8000-000000000001','chr-scale-a','CHR Test A'),
 ('b2000000-0000-4000-8000-000000000002','chr-scale-b','CHR Test B');

-- 10,000 parents, multiple sources and categories, ten variants per parent.
insert into public.products(id,store_id,title,handle,status,vendor,product_type,created_by)
select gen_random_uuid(),'a1000000-0000-4000-8000-000000000001'::uuid,
  (array['Four mixte','Armoire réfrigérée','Table inox','Friteuse double','Lave-vaisselle','Four convection',
         'Hotte professionnelle','Cellule de refroidissement','Vitrine réfrigérée','Plancha professionnelle'])[1+(n%10)]
  ||' CHR série '||lpad(n::text,5,'0'),
 'chr-stg-a-'||lpad(n::text,5,'0'),'active',
 'Fournisseur test '||lpad((n%100)::text,3,'0'),
 (array['Cuisson','Froid','Inox','Laverie','Préparation','Ventilation','Boulangerie','Mobilier',
         'Hygiène','Stockage','Accessoires','Buffet','Pâtisserie','Glacerie','Rôtisserie',
         'Boissons','Service','Conditionnement','Fourneau','Réserve'])[1+(n%20)],
 '11000000-0000-4000-8000-000000000001'::uuid
from generate_series(1,10000) as n;

-- Triggers synchronize the actual production projection for every SKU.
insert into public.product_variants(id,store_id,product_id,title,sku,price_minor,weight_grams,taxable)
select gen_random_uuid(),p.store_id,p.id,
 'Modèle '||v::text,
 'CHR-STAGING-'||p.handle||'-'||lpad(v::text,2,'0'),
  10000+(substring(p.handle from '([0-9]{5})$')::integer*41)+(v*700),
  1200+(v*150),v<>10
from public.products p
cross join generate_series(1,10) v
where p.store_id='a1000000-0000-4000-8000-000000000001'::uuid
order by p.handle,v;

-- Deliberately distinct tenant, never eligible for owner A private reads.
insert into public.products(id,store_id,title,handle,status,vendor,product_type,created_by)
select gen_random_uuid(),'b2000000-0000-4000-8000-000000000002'::uuid,
 'PRIVATE TENANT B equipment '||n,'tenant-b-'||lpad(n::text,4,'0'),
 'active','Confidential B','Cuisson','22000000-0000-4000-8000-000000000002'::uuid
from generate_series(1,50) n;
insert into public.product_variants(store_id,product_id,title,sku,price_minor)
select p.store_id,p.id,'Private B','B-PRIVATE-'||p.handle,14900
from public.products p where p.store_id='b2000000-0000-4000-8000-000000000002'::uuid;

analyze public.products;
analyze public.product_variants;
analyze public.storefront_catalog;
select
 (select count(*) from public.products where store_id='a1000000-0000-4000-8000-000000000001') as tenant_a_parents,
 (select count(*) from public.product_variants where store_id='a1000000-0000-4000-8000-000000000001') as tenant_a_skus,
 (select count(*) from public.storefront_catalog where store_id='a1000000-0000-4000-8000-000000000001') as tenant_a_catalog,
 (select count(*) from public.storefront_catalog where store_id='b2000000-0000-4000-8000-000000000002') as tenant_b_catalog;
