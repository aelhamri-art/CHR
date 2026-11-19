# CHR — Dossier de reprise et d'audit indépendant (version de travail)

**État : NO-GO production / NO-GO certification.** Ce document décrit la réalité technique et les preuves attendues. Il ne constitue ni un rapport d'audit externe ni une déclaration de conformité.

## 1. Chaîne de traçabilité
- Dépôt source : `aelhamri-art/CHR`. Branches d'intégration successives `audit/shopify-admin-parity`, `feat/chr-admin-github-native`, `feat/chr-storefront-experience`, `feat/chr-hero-search-v2`, `feat/chr-scale-100k-security-hardening`.
- Base Supabase existante : `dkisxdquvryoddpphgeg` (CHR). Les migrations de la branche doivent être confrontées à `supabase_migrations.schema_migrations` avant toute nouvelle exécution.
- Interface admin : `/index.html`, `src/app.js`, `src/api.js`, `src/schema.js`.
- Site client : `/storefront/index.html`, `storefront/src/main.js`, `storefront/src/api.js`, `storefront/src/hero-search.js`.
- SQL métier : `supabase/migrations/`; tests SQL : `supabase/tests/`.
- **La PR #5 reste draft ; ne pas confondre code mis en branche, migrations déjà appliquées et code `main` déployé.** La prévisualisation Lovable CHR n'est pas synchronisée.

## 2. Modèle d'accès à examiner
| Acteur | Catalogue publié | Profil client | Commandes financières | Administration produit |
|---|---|---|---|---|
| anon | Lecture projection seulement si boutique publiée | Non | Non | Non |
| client authentifié | Identique à anon | Ses données via RLS | Ses propres devis seulement | Non |
| employé boutique | Lecture selon rôle | Selon rôle explicite | Selon rôle explicite | Selon rôle |
| owner/admin | Données de sa boutique | Selon règles de traitement | Selon rôle explicite | Oui |
| autre boutique | Jamais de fuite transversale | Jamais | Jamais | Jamais |

La vérification doit utiliser des identités réellement distinctes avec traces HTTP et SQL, y compris les accès `anon` et `authenticated`.

## 3. Flux sensibles
- **Catalogue public** : tables internes `products`/`product_variants` → projection `storefront_catalog` → lecture RLS via RPC SECURITY INVOKER `chr_catalog_*`. Ne pas exposer `cost_minor`, `metadata` ou métadonnées internes.
- **Panier** : identifiants/quantités localement, puis relecture des références autorisées par `chr_catalog_cart_lines`. Prix navigateur informatifs uniquement ; total final à confirmer exclusivement serveur.
- **Devis** : Auth utilisateur + `storefront_customers` → `request_storefront_quote` contrôle existence, prix, limite et idempotence ; aucune autorisation de fixer soi-même un montant.
- **Commande** : RPC transactionnelles, réserve physique des stocks et anti-rejeu ; aucune écriture directe aux tables transactionnelles depuis le navigateur.
- **Paiements** : confirmation humaine de règlement manuel seulement ; flux de carte sauvegardée et remboursement PSP **non implémentés**. Ne jamais déclarer PCI DSS conforme.
- **Médias** : bucket Storage à lecture publique pour images publiées, écriture conditionnée par tenant et type de fichier ; revoir la visibilité des fichiers attachés à des brouillons.
- **Authentification** : sessions Supabase ; recherche d'escalade de rôle, refresh token, abus signup/recovery, protections de mot de passe compromis.

## 4. Critères d'entrée audit
1. Une documentation de l'architecture déployée **avec versions exactes**.
2. Migrations rejouables sur base vierge de STAGING ; tests de restauration et réversibilité.
3. Deux tenants et cinq rôles représentatifs, données de test non personnelles.
4. Politique de gestion des secrets, inventaire des dépendances (SBOM), licences tierces.
5. Tests d'intégration auth, RLS, opérations financières, idempotence et double réservation.
6. Scan SAST, secret scan et dépendances automatisés ; revue manuelle des RPC SECURITY DEFINER.
7. Mesures de charge, instrumentation PostgreSQL, procédures d'alerting et rollback.
8. Domaines HTTPS, CSP, configuration CORS, rate limiting, protections anti-abus et continuité d'activité vérifiés.
9. Documentation RGPD validée par un professionnel compétent, accords de sous-traitance et conservation.
10. Rapport contradictoire indépendant avec preuves, sévérités, corrections et contre-tests.

## 5. Décision de libération
- **P0** : fuite inter-tenant, paiement indu, survente, contournement de politique d'auth, secrets exposés, SQL injection ou exécution arbitraire => blocage absolu.
- **P1** : crash sur parcours principal, prix incohérent, pertes de panier/devis, données personnelles visibles à mauvais rôle, indisponibilité persistante => blocage.
- Pas de GO si les preuves E2E, charge ou restauration manquent ; les tests unitaires verts ne remplacent jamais ces preuves.
- Les auditeurs externes décident de leur avis. Aucun outil ou fournisseur ne peut en garantir le résultat.
