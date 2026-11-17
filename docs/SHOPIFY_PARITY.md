# Audit de couverture Shopify Admin — AXIUM Commerce OS (référence 17/11/2026)

**État : INVENTAIRE INITIAL, NON EXHAUSTIF. Aucune fonctionnalité marquée réalisée.** Cet inventaire reprend les catégories publiques vérifiables : il ne prouve pas l'accès aux parcours internes, aux fonctionnalités propres à certains abonnements ou aux applications tierces.

## Règle de couverture
Chaque ligne doit faire l'objet d'une fiche parité `SHOP-XXX` : capture/parcours Shopify observable, préconditions, droits, données requises, inputs/validations, états, actions, erreurs, effets métier, cas limites, tests automatisés, preuve UI+API+DB, statut, lien PR. `DONE` exige CI verte ET recette E2E.

**Statuts possibles :** NON AUDITÉ / SPÉCIFIÉ / EN COURS / IMPLÉMENTÉ / TESTÉ / VALIDÉ / BLOQUÉ / EXCLU. Tous les éléments ci-dessous : NON AUDITÉ, NON IMPLÉMENTÉ.

**Bornes de parité :** fonctions natives de Shopify Admin, selon plans et marchés documentés. Le produit Shopify Payments, ses fonds bancaires, Shop Pay, Shopify Capital, Shopify POS matériel, l'App Store et les marques ne peuvent pas être copiés ; les équivalents nécessitent des prestataires tiers et des intégrations distinctes. Les abonnements, langues ou pays affectent l'inventaire cible.

## Registre initial — couverture produit

### Administration & navigation

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-001 | Accueil : indicateurs, alertes et raccourcis contextualisés | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-002 | Navigation globale et recherche transversale | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-003 | Filtres, tris, vues sauvegardées, pagination | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-004 | Actions en masse avec confirmations et permissions | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-005 | Notifications, tâches prioritaires et état de synchronisation | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-006 | Journal d'activité et historique détaillé | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-007 | Paramètres de l'organisation et fuseaux horaires | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-008 | Préférences individuelles et accessibilité | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Catalogue

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-009 | Création/édition/archivage/suppression/restauration produit | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-010 | Titres, descriptions enrichies, médias, SEO, handles | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-011 | Statuts brouillon/actif/archivé et canaux | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-012 | Catégories normalisées, types, fabricants, fournisseurs, tags | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-013 | Prix, compare-at, coût d'achat, marges, taxes | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-014 | Variantes, options, valeurs, combinaisons et limites | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-015 | SKU, GTIN, codes-barres, poids, unité et dimensions | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-016 | Images, vidéos et fichiers attachés par variante | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-017 | Métachamps typés, définitions, validations | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-018 | Métaobjets personnalisés et relations | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-019 | Import/export CSV avec aperçu, validation et gestion erreurs | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-020 | Duplication produit, édition en masse, rollback | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-021 | Produits numériques, physiques, bundles et précommandes | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-022 | Collections manuelles et collections automatiques | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-023 | Règles de collection AND/OR, condition sur attribut/métachamp | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-024 | SEO et publication des collections | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-025 | Listes de prix par catalogue/marché/client | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Inventaire & emplacements

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-026 | Emplacements et entrepôts multiples | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-027 | Stock par SKU et emplacement | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-028 | Disponible, engagé, réservé, entrant, non disponible | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-029 | Ajustements de stock motivés et journalisés | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-030 | Transferts inter-emplacements et réceptions | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-031 | Seuils et alertes de réapprovisionnement | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-032 | Réservations atomiques empêchant la survente | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-033 | Règles d'allocation et sélection de site | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-034 | Stocks négatifs et règles de poursuite des ventes | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-035 | Inventaire physique et rapprochement | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Commandes & devis

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-036 | Recherche, filtres et vues commandes | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-037 | Commande manuelle et brouillon/devis | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-038 | Lignes, variantes, taxes, remises, frais et adresses | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-039 | Conversion devis en commande, facture/bon de commande | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-040 | États paiement, préparation, retour, livraison séparés | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-041 | Édition post-commande avec recalcul et delta financier | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-042 | Annulation contrôlée avec libération réservations | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-043 | Paiement partiel, captures, remboursements et avoirs | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-044 | Expéditions partielles, scissions, suivi multi-colis | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-045 | Retours, échanges, restock et règles de retour | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-046 | Étiquettes, bons de préparation et documents | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-047 | Anti-doublons/idempotence commandes et webhooks | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-048 | Historique immuable des transitions d'état | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-049 | Abandons panier et récupération | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Clients & B2B

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-050 | Fiches clients, emails, téléphones, adresses | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-051 | Historique commandes, panier, retours et interactions | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-052 | Segments statiques/dynamiques et tags | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-053 | Consentements RGPD, opt-in/out marketing | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-054 | Entreprises B2B, sites, contacts et rôles | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-055 | Grilles tarifaires B2B et net terms | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-056 | Exemptions de taxe et justificatifs | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-057 | Fusion des doublons et export/effacement des données | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-058 | Notes internes, confidentialité et autorisations | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Livraison, logistique & taxes

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-059 | Profils de livraison par produits et origines | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-060 | Zones par pays/région/code postal | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-061 | Tarifs fixes, tranches de prix et poids | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-062 | Tarifs gratuits conditionnels | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-063 | Poids, dimensions, colis, poids volumétrique | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-064 | Tarifs transporteur calculés via API et fallback | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-065 | Exceptions et exclusions produits/zones | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-066 | Calcul de tarifs combinés sur panier multi-profils | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-067 | Retrait magasin, livraison locale, créneaux | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-068 | Points relais et choix de transporteur | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-069 | Étiquettes, tracking, confirmations d'envoi | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-070 | Règles de livraison selon marché | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-071 | TVA par pays/catégorie et prix TTC/HT | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-072 | Exemptions, taxation livraison, droits de douane | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-073 | Reproductibilité du calcul du checkout | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Paiements & finances

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-074 | Configuration PSP et moyens de paiement | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-075 | Modes test/production et gestion secrets | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-076 | Autorisation, capture, remboursement, annulation | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-077 | Idempotence et vérification cryptographique des webhooks | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-078 | Transactions, rapprochement et export | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-079 | Paiements manuels et virements contrôlés | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-080 | Détection/refus des montants incohérents | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-081 | Cartes cadeaux, avoirs, crédit boutique | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-082 | Factures, documents et exports comptables | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-083 | Rapports CA brut/net, taxes, remises, frais | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Marchés internationaux

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-084 | Marchés par pays et groupes de pays | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-085 | Disponibilités de produit par marché | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-086 | Monnaies, taux de change et arrondis | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-087 | Tarifs fixes et ajustements de prix par marché | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-088 | Domaines/sous-domaines et langues | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-089 | Taxation, affichage prix TTC/HT et droits | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-090 | Restrictions de paiement et de livraison par marché | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-091 | Catalogue B2B et segmentation des marchés | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-092 | Prévisualisation du panier/checkout par marché | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Marketing, promotions & contenu

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-093 | Codes promo durée, limites et conditions | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-094 | Réductions auto et règles de cumul | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-095 | Coupons par produit/collection/commande/livraison | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-096 | Programmes cadeaux et crédits | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-097 | Campagnes, sources et attribution | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-098 | Automatisations et déclencheurs métier | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-099 | Pages, fichiers, menus et contenus structurés | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-100 | Recherche produit, filtres et SEO | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-101 | Notifications transactionnelles paramétrables | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Checkout & canaux

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-102 | Panier, calculs serveur et taxes finales | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-103 | Checkout sécurisé, adresse et choix expédition | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-104 | Validation tarifs, stocks et prix au paiement | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-105 | Paiement confirmé par événement vérifié | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-106 | Échecs, reprises, anti-double soumission | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-107 | Comptes clients et réinitialisation accès | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-108 | Canaux de vente et publication sélective | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-109 | Webhooks et connecteurs vers applications externes | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Configuration, sécurité & exploitation

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-110 | Utilisateurs, rôles et permissions granulaires | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-111 | Authentification, sessions, MFA si disponible | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-112 | Isolation tenant et policies RLS testées | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-113 | Audit trail avant/après et auteur | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-114 | Corbeille/restauration données compatibles | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-115 | Backups et plan de restauration testé | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-116 | Exports, portabilité et rétention RGPD | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-117 | Journal des jobs, retries et dead letter | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-118 | Gestion secrets et séparation environnements | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-119 | Observabilité, erreurs, alertes, métriques | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-120 | Accessibilité mobile/tablette/clavier | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-121 | Documentation technique et manuel administrateur | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

### Préparation Aximus

| ID | Fonction / comportement | État | Critère de réception de base |
|---|---|---|---|
| SHOP-122 | Catalogue versionné d'actions métier invocables | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-123 | Schémas d'entrée stricts et validation serveur | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-124 | Dry-run/diff avant modification | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-125 | Permissions identiques humain/agent | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-126 | Confirmations pour opérations à impact fort | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-127 | Idempotence et compensation/reprise | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-128 | Historique requête, outils, auteur, résultat | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |
| SHOP-129 | Aucun agent actif livré tant que hors périmètre | NON AUDITÉ | État persistant, règle serveur, permissions et tests E2E vérifiés |

## Références Shopify consultées

- Admin : https://help.shopify.com/en/manual/shopify-admin
- Produits : https://help.shopify.com/en/manual/products
- Collections : https://help.shopify.com/en/manual/products/collections/create-collection
- Commandes : https://help.shopify.com/en/manual/fulfillment/managing-orders
- Livraison : https://help.shopify.com/en/manual/fulfillment/setup/shipping-rates/setting-up-shipping-rates
- Marchés : https://help.shopify.com/en/manual/markets
- Finance : https://help.shopify.com/en/manual/finance
- Checkout : https://help.shopify.com/en/manual/checkout-settings/
- Historisation : https://help.shopify.com/en/manual/shopify-admin/activity-logs
- Permissions : https://help.shopify.com/en/manual/your-account/users/roles/permissions/store-permissions
- API : https://shopify.dev/docs/api/admin-graphql/latest

## Méthode d'audit complémentaire
1. Cartographier tous les menus et sous-menus du plan Shopify retenu et leurs variations selon pays/plan.
2. Inspecter écran, onglet, modale, champ, type, valeur par défaut, validation, erreur, permission et conséquence métier.
3. Reconstituer les machines à états (commandes, paiements, stocks, expédition, retours).
4. Établir jeux de données limites (panier multi-entrepôts, taxations, zones disjointes, remboursements partiels, etc.).
5. Rattacher tests automatiques et captures à chaque ID ; compter la couverture réelle par fonctions pondérées.

**Nombre d'exigences inventoriées initialement : 129. Ne pas confondre ce nombre avec le nombre total de fonctionnalités Shopify.**
