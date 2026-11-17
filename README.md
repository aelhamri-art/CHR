# AXIUM Commerce OS — CHR

**Statut : cadrage technique / aucun module métier livré.** Projet piloté par AXIUM Studios, première entreprise pilote : CHR.

## Mandat
Créer un back-office de commerce à **parité fonctionnelle vérifiée avec Shopify Admin**, avec identité propre AXIUM Commerce OS. Aucune dépendance à Shopify n'est présumée. **Aximus n'est pas implémenté** : préparer des actions métier sûres, versionnées, autorisées, journalisées et invocables ultérieurement.

La parité ne signifie pas copie du code, des éléments graphiques propriétaires, des services financiers Shopify ou de son App Store. Les comportements à reproduire doivent être spécifiés et testés individuellement.

## Infrastructure confirmée au 17/11/2026
- GitHub : `aelhamri-art/CHR` (dépôt **public** à sécuriser avant tout code secret ou donnée client).
- Supabase : projet `CHR`, ref `dkisxdquvryoddpphgeg`, Postgres 17, `eu-west-1`, aucune table métier initialement.
- Lovable : espace Adam's Lovable. Un projet Lovable ne se lie pas directement par Git Sync à ce dépôt existant : documenter toute synchronisation ou export manuels.

## Doctrine de livraison
- Aucune fonctionnalité déclarée terminée sans test de bout en bout avec données persistées et vérification des permissions.
- Aucun calcul commercial (montants, taxes, stock, livraison, paiements) exclusivement en frontend.
- Pas de stockage des données de carte bancaire ; connecter un PSP conforme via API et webhooks.
- Migrations SQL versionnées, RLS partout dans les schémas exposés, contrôle serveur de la portée entreprise.
- CI obligatoire : format, lint, types, tests unitaires, intégration, E2E des parcours P0, audit dépendances.
- Distinction nette entre `implementé`, `testé`, `intégré`, `bloqué`, `hors périmètre`.

## Dossiers
- `docs/SHOPIFY_PARITY.md` : matrice de référence et critères de réception.
- `docs/ARCHITECTURE.md` : architecture cible, frontières de confiance, principes de cohérence.
- `docs/QUALITY_GATES.md` : critères de qualité premium et GO/NO-GO.

## État réel
Ce premier commit est documentaire. Il ne constitue pas une livraison commerciale exploitable.
