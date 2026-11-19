# CHR — Gouvernance de livraison obligatoire

Une version n'est pas publiée directement depuis une branche de développement :
1. PR indépendante, code review et historique de migrations SQL.
2. Tests unitaires et règles statiques + lint, type checking lorsque TypeScript est utilisé.
3. Tests d'intégration Supabase (anonyme, client, support, manager, owner, autre tenant).
4. Tests E2E desktop, mobile 320/390 et lecteur d'écran + clavier.
5. Tests concurrence, prix, stocks, devis, remboursements et paiements selon flux effectivement actifs.
6. Scans de sécurité et revue humaine OWASP ASVS L2 sur les domaines applicables.
7. Recette fonctionnelle d'Ahmed sur des produits vrais, TVA, livraison et CGV approuvées.
8. Mesures p95/p99 sur 100k références dans un staging de capacité comparable.
9. Backups, PITR, restauration, rollback et incident runbook validés.
10. Responsable habilité autorise la mise en production; version/commit explicitement enregistrés.

**État 19 novembre 2026 : NO-GO.** Nouveau backend indexé développé, tests SQL avec 55 variantes temporaires passés. Aucune campagne 100k, revue indépendante ou vraie recette multi-tenant authentifiée réalisée à ce stade.

## Risques d'architecture encore ouverts
- L'admin a une nouvelle pagination 50 références ; certains sélecteurs de relation et exports complets sont encore limités à 1000 lignes.
- Fichiers HTML/JS natifs de la première version : pas de SSR/SEO complet, ni écosystème de composants typés équivalent au standard React TS désiré.
- Pas de service PSP, tokenisation CB, facture ou webhooks signés déployés.
- Le storefront Lovable « CHR » n'est pas synchronisé avec le dépôt GitHub CHR.
- Personne n'a démontré une tolérance à panne ou un PRA satisfaisant.
