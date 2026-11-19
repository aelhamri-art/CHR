# BKS CHR — Preuves techniques 100 000 SKU, intégrité et isolation
**Date : 19 novembre 2026 — statut : validation partielle, NO-GO production**

## Identifiant de preuve et reproductibilité
- Projet : [aelhamri-art/CHR](https://github.com/aelhamri-art/CHR), PR [#5](https://github.com/aelhamri-art/CHR/pull/5) (DRAFT).
- Commit exact testé : `5c4b4806fdab518a2ae69976bfefa813779828d7`.
- [Exécution GitHub Actions réussie #44621583770](https://github.com/aelhamri-art/CHR/actions/runs/44621583770) avec artefact **chr-postgres-100k-verifiable-evidence** ; contrôles CodeQL/Quality/Visual également verts sur ce commit.
- Environnement **éphémère** GitHub Actions Ubuntu runner, PostgreSQL **17.12**, 4 vCPU AMD EPYC 9V74. Ce n'est **pas** la machine Supabase de production, ni un test réseau HTTP.
- Les **23 migrations SQL CHR versionnées** ont été rejouées sur une base vierge. Le fichier `.github/workflows/chr-postgres-100k.yml` définit le protocole.
- Les preuves d'audit comprennent logs de migrations, création des données, RLS, régresseurs, concurrence (32 sessions), p50/p95/p99, EXPLAIN ANALYZE et données CSV (sans PII).

## 1. 100 000 références : contrôle intégral

| Mesure | Résultat prouvé |
|---|---:|
| Produits parents entreprise A | 10 000 |
| SKU/variantes entreprise A | **100 000** |
| Variantes dans la projection réellement synchronisée par triggers | **100 000** |
| SKU distincts entreprise B | 50 |
| Catégories de données générées | 20 |
| Fournisseurs synthétiques | 100 |
| Taille de pagination parcourue | 48 |
| Nombre de pages effectivement parcourues | **2 084** |
| Identifiants distincts comptabilisés | **100 000** |
| Doublons / trous lors du parcours | **0 / 0** |

Les lignes ont été réellement insérées dans PostgreSQL, contraintes, triggers, RLS et fonctions SQL CHR activés. Ce n'était pas une réponse de service simulée.

## 2. Performance après correctifs

Dans une session propriétaire autorisée, requêtes SQL mesurées sans HTTP, sans cache CDN, sans navigateur et **sans requêtes simultanées**.

| Opération | Échantillon | p50 | p95 | p99 |
|---|---:|---:|---:|---:|
| Page catalogue | 30 | voir CSV | **469,46 ms** | **567,53 ms** |
| Suggestions de recherche | 30 | voir CSV | **299,52 ms** | **364,70 ms** |
| Fiche produit | 20 | voir CSV | **0,42 ms** | **0,99 ms** |

Historique honnête des incidents : un premier essai a dépassé le délai de 12 minutes dans la fonction de suggestions. Le second diagnostic donnait **2 333,09 ms au p95** pour la page et **5 349,47 ms** pour les suggestions. Une optimisation des index, puis de la politique RLS avec ensemble de boutiques autorisées calculé une fois par instruction, a donné les résultats finaux ci-dessus. Les traces des échecs restent conservées dans les historiques Actions précédents.

**Qualification :** l'objectif exploratoire p95 de 500 ms côté SQL est atteint sur **ce jeu de 30 requêtes**. Un échantillon de 30, sans charge concurrente ni réseau, ne constitue **pas** un SLO de production ; le p99 catalogue est déjà supérieur à 500 ms.

## 3. Intégrité financière et concurrence

Tests SQL réels `supabase/tests/005` à `009` réussis, dont :
- mouvements de stock idempotents : même clé = un mouvement ; clé réutilisée avec quantité différente = rejet ;
- TVA des lignes taxables / exonérées + TVA transport selon règle ; réservation puis annulation avec libération ;
- protection du prix figé des devis contre modification après création ;
- projections produits synchronisées à l'insertion, mise à jour, suppression et archivage ;
- import de 10 SKU liés au même parent, réimportation sans réécriture et mise à jour ciblée.

**Épreuve multi-session indépendante** (`benchmarks/100k/pg17-concurrency-*.sql`) :
- 16 requêtes concurrentes, 16 clés différentes, 1 unité en stock : **1 commande créée / 15 refus pour stock insuffisant** ;
- 16 requêtes concurrentes, même clé, seconde unité : **1 commande créée / 15 résultats `already_created`** ;
- contrôle de la base après : **2 commandes totales, 2 lignes, 2 clés uniques, 2 réservations sur 2 unités** ; montants par commande : 10 000 centimes de sous-total + 1 000 de transport + 2 200 de TVA = 13 200 centimes.
- Les sorties de chaque session sont jointes dans `concurrency/`.

Cette preuve ne valide pas les paiements PSP ni les webhooks, ni un test prolongé à forte concurrence.

## 4. Isolation entre entreprises

Sur la base éphémère ont été créés **deux utilisateurs distincts dans la table synthétique `auth.users`**, deux magasins et deux jeux de données. Le test `pg17-rls-two-tenants.sql` émet de vraies requêtes PostgreSQL en rôle `authenticated` avec `request.jwt.claim.sub` différent (sans authentification HTTP réelle).

Résultats :
- A peut lire les 100 000 SKU de A sans voir les 50 SKU privés de B ;
- B peut lire ses 50 SKU, mais ne peut lire, modifier, supprimer ou insérer des produits dans A ;
- les fonctions `chr_admin_catalog_page`, `chr_catalog_page` et `chr_catalog_suggest` respectent la séparation ;
- une tentative d'élévation avec `user_metadata.role='superadmin'` ne contourne pas les politiques ;
- le rôle anonyme ne voit aucun catalogue non publié.
- Les mêmes tests de transactions ont été réexécutés sur la base contenant 100 000 SKU.

**Limites :** ni attaque sur de vrais JWT signés Supabase, ni API HTTP PostgREST en production, ni tests de session expirée/refresh, ni audit indépendant complet.

## 5. Décision et bloqueurs encore ouverts

- **PASS — capacité structurelle 100 000 références** sur PostgreSQL 17 éphémère.
- **PASS — cohérence du parcours 2 084 pages** sans duplicata.
- **PASS — première performance SQL diagnostique**, p95 469 ms page, 300 ms suggestions, avec limites de mesure.
- **PASS — absence de survente et idempotence** pour 32 commandes concurrentes de test.
- **PASS — isolation SQL des deux tenants synthétiques** avec attaques de métadonnées.
- **NO-GO — production et audit final**, car manque encore : staging Supabase de ressources équivalentes, tests de charge HTTP avec trafic simultané et 100k SKU, vrai processus Auth multi-tenant, PSP/webhooks, restauration et PRA, pentest indépendant, correction/revue des sept avertissements de fonctions SECURITY DEFINER, protection des mots de passe compromis, parcours de vente réels, CGV, déploiement et validation d'Ahmed.
- Les nouvelles optimisations du catalogue et de la RLS **ne sont présentes que sur la branche de développement et sur la base GitHub Actions testée** ; elles ne doivent pas être considérées déployées en production.
- Aucun staging Supabase facturable n'a été créé (l'outil exige l'approbation préalable du coût).
- Ne fusionner la PR et ne publier la boutique qu'après revue de sécurité et des procédures d'exploitation.

**Conclusion : le mandat de démonstration de la capacité de données et des invariants transactionnels SQL est documenté et réussi pour cet environnement contrôlé. La preuve de robustesse complète de l'application commerciale en production reste à obtenir.**
