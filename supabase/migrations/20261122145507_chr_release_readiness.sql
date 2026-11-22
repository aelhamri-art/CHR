-- AXIUM OS: deterministic, authenticated launch readiness for the CHR operator.
-- Does NOT claim security certification, backup restoration or final acceptance.
create or replace function public.chr_release_readiness(p_store_id uuid)
returns jsonb language plpgsql stable security invoker set search_path=''
as $ready$
declare
 v_products bigint;
 v_variants bigint;
 v_photos bigint;
 v_warehouse bigint;
 v_rates bigint;
 v_taxes bigint;
 v_contacts bigint;
 v_clients bigint;
 v_stock bigint;
 v_storefront record;
 v_checks jsonb;
begin
 if auth.uid() is null or not app_private.can_read_store(p_store_id) then
  raise exception 'Access denied' using errcode='42501';
 end if;
 select count(*) into v_products from public.products
  where store_id=p_store_id and status='active';
 select count(*) into v_variants from public.product_variants v
  join public.products p on p.store_id=v.store_id and p.id=v.product_id
  where v.store_id=p_store_id and p.status='active';
 select count(distinct p.id) into v_photos from public.products p
  join public.product_media pm on pm.store_id=p.store_id and pm.product_id=p.id
  where p.store_id=p_store_id and p.status='active';
 select count(*) into v_warehouse from public.locations
  where store_id=p_store_id and active=true;
 select count(*) into v_rates from public.shipping_rates
  where store_id=p_store_id and enabled=true and mode<>'carrier';
 select count(*) into v_taxes from public.tax_rules
  where store_id=p_store_id and active=true;
 select count(*) into v_clients from public.customers
  where store_id=p_store_id;
 select count(*) into v_stock from public.inventory_levels
  where store_id=p_store_id and on_hand>reserved;
 select * into v_storefront from public.storefront_settings where store_id=p_store_id;
 v_checks:=jsonb_build_array(
  jsonb_build_object('key','catalog','label','Catalogue actif','status',
   case when v_products>0 and v_variants>0 then 'pass' else 'block' end,
   'details',v_products||' produits actifs · '||v_variants||' SKU'),
  jsonb_build_object('key','media','label','Photos produit validées','status',
   case when v_photos>0 then 'pass' else 'block' end,
   'details',v_photos||' produits actifs avec photo'),
  jsonb_build_object('key','warehouse','label','Entrepôt opérationnel','status',
   case when v_warehouse>0 then 'pass' else 'block' end,
   'details',v_warehouse||' emplacement(s) actifs'),
  jsonb_build_object('key','delivery','label','Tarifs de livraison exploitables','status',
   case when v_rates>0 then 'pass' else 'block' end,
   'details',v_rates||' tarif(s) locaux autorisés'),
  jsonb_build_object('key','tax','label','Fiscalité configurée','status',
   case when v_taxes>0 then 'pass' else 'block' end,
   'details',v_taxes||' règle(s) TVA active(s)'),
  jsonb_build_object('key','storefront','label','Configuration de la boutique','status',
   case when v_storefront.store_id is not null then 'pass' else 'block' end,
   'details',coalesce(v_storefront.public_slug,'Aucun slug public configuré')),
  jsonb_build_object('key','contact','label','Email public du vendeur','status',
   case when coalesce(v_storefront.contact_email,'') ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    then 'pass' else 'block' end,
   'details','Une adresse officielle de contact doit être fournie'),
  jsonb_build_object('key','legal','label','Documents juridiques approuvés','status',
   case when length(coalesce(v_storefront.legal_notice,''))>=100
    and length(coalesce(v_storefront.privacy_policy,''))>=100
    and length(coalesce(v_storefront.terms_of_sale,''))>=100
    then 'pass' else 'block' end,
   'details','Mentions légales, confidentialité et CGV réelles et approuvées'),
  jsonb_build_object('key','stock','label','Disponibilité commerciale','status',
   case when v_stock>0 then 'pass' else 'manual' end,
   'details',case when v_stock>0
    then v_stock||' solde(s) disponibles'
    else 'Aucun stock physique disponible : devis sur commande fournisseur possible' end),
  jsonb_build_object('key','buyers','label','Premier client B2B','status',
   case when v_clients>0 then 'pass' else 'manual' end,
   'details',v_clients||' client(s) enregistrés'),
  jsonb_build_object('key','security_review','label','Audit de sécurité et authentification réelle',
   'status','manual','details','Revue RLS multi-comptes, fonctions privilégiées et protection des comptes'),
  jsonb_build_object('key','backup_restore','label','Restauration de sauvegarde',
   'status','manual','details','Une restauration complète réussie doit être attestée'),
  jsonb_build_object('key','acceptance','label','Recette et autorisation CHR',
   'status','manual','details','Validation explicite du propriétaire et des responsables métier')
 );
 return jsonb_build_object(
  'store_id',p_store_id,
  'published',coalesce(v_storefront.published,false),
  'checks',v_checks,
  'checks_passed',(select count(*) from pg_catalog.jsonb_array_elements(v_checks) ch where ch->>'status'='pass'),
  'checks_blocked',(select count(*) from pg_catalog.jsonb_array_elements(v_checks) ch where ch->>'status'='block'),
  'checks_manual',(select count(*) from pg_catalog.jsonb_array_elements(v_checks) ch where ch->>'status'='manual'),
  'evaluated_at',pg_catalog.now()
 );
end $ready$;
revoke all on function public.chr_release_readiness(uuid)
 from public,anon,authenticated;
grant execute on function public.chr_release_readiness(uuid) to authenticated;
