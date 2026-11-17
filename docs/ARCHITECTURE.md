# Architecture technique cible — décision préliminaire

## Single source of truth
Supabase Postgres `CHR` est la base de données métier. GitHub `CHR` est la source de vérité du code, des migrations et des preuves. Lovable sert à l'édition et à la prévisualisation d'une interface React/TypeScript. La connexion Supabase externe n'est pas encore établie depuis Lovable ; ne jamais prétendre qu'une preview possède des données persistées tant qu'elle ne les utilise pas.

## Frontières et couches
1. UI React/TypeScript (responsive, navigation, composants accessibles), aucun secret et aucun calcul financier faisant autorité côté navigateur.
2. Supabase Auth + rôles métier sur serveur, RLS sur chaque table exposée, tenant_id vérifié.
3. Services de domaine : Catalogue, Pricing, Inventory, Checkout, Orders, Shipping, Tax, Payments, Returns, Marketing, Customers, Auditing, Settings.
4. Fonctions transactionnelles SQL / Edge Functions pour opérations atomiques : réservation, capture, changement de prix, remboursements, allocations, transitions.
5. Adaptateurs : PSP, transporteurs, emails, WhatsApp. Jamais de données carte dans Supabase.
6. Journal append-only avec audit d'intention/diff/exécution/erreurs. Conservation et purges alignées RGPD.
7. Adaptateurs Aximus (non actifs) : registre actions, JSON schema, versionnement, checks RLS, dry-run, confirmations, idempotence.

## Garde-fous
- Prix et TVA calculés en unités monétaires exactes (centimes / decimal), jamais de float pour paiements.
- Idempotence webhook par provider, event ID, transaction et état.
- Réservations de stocks verrouillées au niveau Postgres, pas de simple lecture puis écriture.
- Historique des prix et lignes de commande figées à l'achat.
- Soft delete sous réserve des intégrités et obligations légales.
- Export/suppression de données personnelles soumis à droits, traçabilité et rétention.
- Multi-entreprise prêt dans le modèle, sans ouvrir de droits interentreprises.
- Migrations déployées via environnements de test, puis prod après validation.

## État de l'infrastructure
- Dépôt actuellement public : ne pas y stocker de secrets, contrats, identités clients ou dump.
- La synchronisation Git native de Lovable crée un nouveau dépôt, elle ne se lie pas à un repo existant. Prévoir export/import contrôlé, ou développement principal GitHub avec preview distincte. Source : https://docs.lovable.dev/integrations/github
- Connexion externe Supabase par projet possible. Source : https://docs.lovable.dev/integrations/supabase
- La décision moteur e-commerce maison/Medusa reste à arbitrer selon effort des règles métier et coûts récurrents ; aucun choix n'est déclaré validé par défaut.

## Séquence
Audit exhaustif → périmètre et modèle de données → invariants et contrats API → premier parcours complet (produit→stock→tarif→commande→paiement test→expédition) → modules par groupe → automatisation et QA → audit indépendant → recette.
