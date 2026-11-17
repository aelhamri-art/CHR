# AXIUM Commerce OS — CHR

**GitHub CHR = code. Supabase CHR = base métier. Aucune dépendance de production à Lovable, Medusa ou Shopify.**

## État de développement

Administration codée : authentification, boutique, CRUD produits/variantes/collections/clients/entrepôts/livraison/taxes/réductions, images produits, tableaux, exports CSV, journal et moteur transactionnel des commandes.

Opérations serveur codées : ajustement de stock atomique, éligibilité tarif livraison, création commande avec réservation/idempotence, annulation, validation d'encaissement manuel et expédition.

**NON livré :** paiement CB ou portefeuille électronique, remboursement PSP, étiquettes transporteur, retours/échanges complexes, multi-devises, taxes sophistiquées, métachamps exhaustifs, automatisation collections, facturation, Aximus actif et parité exhaustive Shopify.

## Démarrer

1. Cloner ce dépôt.
2. Vérifier `config.js` (clé Supabase PUBLISHABLE uniquement).
3. Exécuter `npm run verify` (Node >= 22).
4. Exécuter `npm run serve`, puis ouvrir http://localhost:8080.
5. Se connecter via Supabase Auth, créer la boutique, importer les produits, créer le stock, livraisons et taxes.

Le frontend est en JavaScript ES Modules natifs, sans dépendances runtime. Les secrets prestataires ne sont jamais embarqués. Données protégées par Auth/RLS; commandes critiques exclusivement par SQL RPC.

## Déploiement

Serveur statique HTTPS possible après audit et configuration des URL de redirection Supabase. Le dépôt a été identifié public : ne jamais placer d'identifiants ou de données privées dans GitHub. Le système n'est pas encore homologué pour les opérations d'Ahmed.

## Qualité

- `docs/SHOPIFY_PARITY.md` : inventaire initial (non exhaustif).
- `docs/QUALITY_GATES.md` : critères de réception.
- `supabase/migrations/` : changements de base versionnés.
- `supabase/tests/` : tests SQL.
- `.github/workflows/ci.yml` : vérifications du code.

**Statut honnête :** ce dépôt ne représente pas une reproduction fonctionnelle de 100 % de Shopify Admin. Les modules nécessitent une recette utilisateur authentifiée avant GO commercial.

## Storefront client CHR (premier vertical slice)

- Site client indépendant dans `storefront/`, administration dans la racine du dépôt.
- Lancer `npm run serve` à la racine puis ouvrir `http://localhost:8080/storefront/`.
- Branding public et publication contrôlés depuis l'admin, menu **Boutique client**.
- L'accès public est bloqué par défaut jusqu'à la validation des vrais contenus, assets et documents obligatoires.
- Compte client, adresses, favoris, panier persistant, demandes de devis stockées dans Supabase.
- Aucun paiement bancaire ou carte enregistrée réellement disponible sans activation et audit du PSP.
- Tests `npm run verify` et workflow `CHR Storefront Visual QA` (Chromium + captures).
- Rapport : `docs/STOREFRONT_RELEASE_REPORT_2026-11-17.md`.
- **Pas de parité Shopify Admin ni d'expérience commerciale complète certifiée à ce stade.**
