# CHR — Rapport de construction et décision de réception

Date : 17 novembre 2026. Source du code : branche `feat/chr-admin-github-native`, PR #2. Base : Supabase `dkisxdquvryoddpphgeg`.

## Ce qui est présent

- Application indépendante (HTML/CSS/JavaScript ESM), authentification Supabase, sélection/création boutique.
- CRUD persistants : produits, variantes, collections, associations, clients, dépôts, profils/zones/tarifs de livraison, taxes, réductions.
- Médias produits : Supabase Storage avec bucket et RLS par entreprise.
- Stock : niveaux, ajustement serveur atomique et journalisation.
- Commandes : RPC transactionnelles de création, réservations, annulation, paiements manuels confirmés, expédition.
- Import CSV catalogue : lots de 1 à 300 lignes atomiques et idempotents, mapping partiel des colonnes Shopify.
- Consultation : commandes, lignes, transactions, historique d'audit, tableaux calculés, exports CSV.
- Aximus : registre contractuel prévisionnel seulement, aucun agent actif.

## Vérifié

- Structure PostgreSQL : 25 tables publiques avec RLS activée ; tables transactionnelles non inscriptibles directement depuis un navigateur authentifié.
- RPC commandes/import : pas d'accès anonyme et contrôle d'appartenance de boutique en code SQL.
- GitHub CI : syntaxe Node et tests unitaires du module prix/CSV, exécutés automatiquement.
- Audit de structure SQL : contrôles exécutés et réussis.

## Non encore vérifié

- Parcours de bout en bout avec un vrai utilisateur Supabase (création boutique, produits, fichier image, commande, paiement manuel, expédition).
- Tests de concurrence et de contention des stocks sous charge réelle.
- Scénarios de multiples entreprises avec utilisateurs et rôles distincts.
- Compatibilité navigateurs/mobile complète, accessibilité WCAG, performance grande volumétrie.
- Sauvegarde/restauration, tests de reprise et tests indépendants de sécurité.

## Alertes visibles dans Supabase

- SECDEF exposées à `authenticated` : intentionnel pour 7 commandes métier, mais chaque fonction doit être audité contre escalade de privilèges/IDOR.
- 3 tables techniques RLS sans policies + droits révoqués : intentionnel.
- Protection des mots de passe compromis non activée : intervention d'un administrateur Supabase requise.

## Actions humaines obligatoires

1. Paramétrer Supabase Auth (emails, anti-abus, protection des mots de passe compromis, domaine HTTPS).
2. Fournir au moins deux comptes de recette sur des entreprises distinctes et réaliser les tests RLS négatifs.
3. Fournir catalogue et règles fiscales validées ; les montants/poids et taxes ne doivent pas être inventés.
4. Fournir contrat/identifiants PSP pour cartes et remboursements électroniques et contrats transporteurs pour livraison automatisée.
5. Configurer hébergement HTTPS et domaine, après validation de l'application.
6. Exécuter revue de code, test sécurité indépendant et sauvegarde/restauration avant production.

## Fonctions majeures manquantes par rapport à Shopify

Checkout public, paiement CB multi-prestataire, retour/échange/réapprovisionnement partiel, multi-marchés/devises, taxes multicatégories, transporteurs réels, promotions calculées au checkout, collection automatique, métachamps et métaobjets complets, canaux de vente, marketing automation, POS, comptes B2B avancés, facturation, reporting approfondi, toutes les apps/infrastructures propriétaires et autres variantes du catalogue Shopify.

## Décision

**NO-GO PRODUCTION.** Code réel et plusieurs modules opérationnels au niveau API, mais aucune promesse de parité Shopify à 100 %. La PR reste en DRAFT. Ne pas fusionner/déployer comme produit achevé sans recette réelle et correction des P0.
