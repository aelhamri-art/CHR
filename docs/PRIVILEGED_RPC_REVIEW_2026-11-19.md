# CHR — Revue préliminaire des 7 RPC privilégiées (19 novembre 2026)

**Nature** : inventaire interne et vérifications ciblées, pas audit contradictoire ni attestation de sécurité. Le scanner Supabase continue de signaler les 7 fonctions exécutables par \`authenticated\` avec \`SECURITY DEFINER\`. Leur exposition exige une revue manuelle et des tests de privilèges sur des identités réelles avant tout GO.

Toutes les fonctions sont dans \`public\`, \`SECURITY DEFINER\` et \`SET search_path=''\`. Elles sont exposées aux utilisateurs authentifiés, non aux anonymes, et dépendent du contrôle explicite de \`auth.uid()\` + des règles métier. **L'utilisation du rôle \`authenticated\` n'est pas à elle seule une autorisation.**

| Fonction | Finalité et garde | Preuve obtenue | Risque résiduel |
| --- | --- | --- | --- |
| \`adjust_inventory\` | \`can_manage_store\`, SKU/entrepôt même boutique, quantité et motif validés ; verrou d'idempotence par boutique/clé, rejets des replays divergents | \`006_inventory_idempotency_owner_jwt_rollback.sql\` | Rôles internes trop larges à revoir ; charges et tests multi-session à faire |
| \`create_order\` | \`can_manage_store\`, prix recalculés depuis variantes réelles, réservation conditionnelle, idempotence ; locks SKU triés ; TVA des variantes exonérées exclue | \`007_finance_tax_and_quote_snapshot_rollback.sql\` | TVA multi-taux, remises, remboursements, survente sous 100 VU non validés |
| \`cancel_pending_order\` | \`can_manage_store\`, commande impayée/non expédiée seulement, libération réserve, boucle SKU triée | \`007_finance_tax_and_quote_snapshot_rollback.sql\` | Annulation concurrente à rejouer sous tests multi-session |
| \`confirm_manual_payment\` | \`can_manage_store\`, commande ouverte et non payée, texte de confirmation et référence fournie | Revue statique du corps SQL | **Pas de preuve bancaire indépendante** ; contrôle à quatre yeux / rapprochement nécessaire avant GO financier |
| \`fulfill_paid_order\` | \`can_manage_store\`, statut payé et non expédié, mouvement stock atomique, ordre SKU stable | Revue statique, logique SQL inspectée | Transporteur non intégré, doublons/retours/échecs externes à valider |
| \`import_products_batch\` | \`can_manage_store\`, 300 lignes max, validation SKU/prix, lock batch, catégorisation, skip des mises à jour inchangées | \`009_catalog_batch_idempotency_projection_rollback.sql\` | Aucune charge représentative 100k ; reconnaissance fournisseurs, métachamps et mapping avancé incomplets |
| \`request_storefront_quote\` | Auth + profil appartenant au client + boutique publiée, 25 lignes max, prix serveur, 10/jour/client et verrou par client, snapshot immuable | \`007_finance_tax_and_quote_snapshot_rollback.sql\` pour immutabilité | WAF, limites IP, anti-bots, confirmation email et tests concurrentiels encore à faire |

## Tests de permissions et sécurité

- Requêtes SQL \`anon\` : catalogue non publié inaccessible ; refus d'appel des RPC financières.
- Simulation SQL de \`auth.uid()\` propriétaire : accès RLS aux boutiques de l'utilisateur valide.
- Simulation SQL d'un autre UUID : aucun magasin, produit interne, profil client ni devis visible.
- Tests \`006\`, \`007\`, \`008\`, \`009\` : fixtures annulées par ROLLBACK, sans modification persistante.
- **Limitation** : la base reliée comporte actuellement un seul propriétaire/compte authentifié. Il faut deux *vrais* utilisateurs de deux boutiques indépendantes dans un staging pour prouver l'absence de BOLA/IDOR inter-entreprises en conditions réseau HTTP/API.
- Le scan CodeQL automatise certains contrôles statiques. Sa réussite d'exécution ne prouve pas l'absence de vulnérabilités et les alertes doivent être analysées séparément.

## Avis de sécurité Supabase à ne pas masquer

Dernière revue de travail : 7 avertissements \`authenticated_security_definer_function_executable\` (exposition intentionnelle à revalider) ; 1 avertissement \`auth_leaked_password_protection\` (protection des mots de passe compromis non activée) ; 3 informations \`rls_enabled_no_policy\` sur tables internes bloquées. Ces avis doivent être documentés et soldés/risk-acceptés par un responsable sécurité.

## Décisions de blocage

**NO-GO paiements** tant que les RPC manuelles n'ont pas de garde de fraude proportionnée, un rapprochement bancaire, une identité renforcée et des tests de concurrence. **NO-GO 100k** tant qu'un staging dédié n'a pas chargé 100k SKUs et mesuré des latences p95/p99. **NO-GO sécurité** tant que les tests utilisateurs réels inter-tenants, analyse dépendances/stockage, pentest et revue des transactions ne sont pas effectués.
