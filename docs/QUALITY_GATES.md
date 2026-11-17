# Quality Gates — AXIUM Commerce OS

**Pas de livraison proclamée '100% Shopify' sans preuves.**

## Définition de 'terminé'
- Fonctionnalité tracée à un ID SHOP, sources, écran, cas d'erreur et autorisations.
- Stockage réel ; refresh, déconnexion/reconnexion, multi-session, permissions.
- Calculs et invariants vérifiés côté serveur ; pas de mock masqué.
- Unit + integration + E2E Playwright et tests de non-régression.
- Audit sécurité Auth/RLS/IDOR/CSRF/XSS/injection/secrets/webhooks, dépendances et logs.
- Recette UX clavier, lecteurs d'écran de base, responsive 320px à desktop, performance et états de chargement.
- Observabilité, sauvegarde/restitution, gestion panne fournisseur, plan rollback.

## P0 : bloquants
1. Un utilisateur accède aux données d'une autre entreprise.
2. Paiement comptabilisé deux fois, remboursement double, webhook rejoué non idempotent.
3. Une commande réserve/vend plus de stock que permis.
4. Montant total, taxe ou livraison différent entre paiement et commande.
5. Données modifiables après validation sans trace et sans droits.
6. Un mode test appelle le PSP réel ou un mode prod utilise des données de démonstration.
7. Une opération Aximus hors rôle devient possible par appel direct à l'API.

## GO / NO-GO
- Tous les P0 passent en CI et en recette.
- Aucun secret dans le frontend, dépôt ou historique.
- Aucune erreur critique sécurité et aucune vulnérabilité critique non corrigée.
- RLS testée sur chaque table exposée, y compris via RPC et vues.
- Sauvegarde et restauration réellement testées.
- Score de parité = fonctionnalités *validées* / fonctionnalités *auditées et retenues*, avec périmètre versionné.
- Fonctionnalités externes marquées 'intégration dépendante' plutôt que '100% natif'.
- Revue humaine indépendante recommandée pour toute prétention de niveau mondial.
