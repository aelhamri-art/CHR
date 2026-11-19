# CHR — Modèle de menaces initial, à valider avec un cabinet indépendant

**Périmètre** : web client, web admin, Supabase Auth/PostgREST/PostgreSQL/Storage, GitHub Actions, accès réseau et opérations humaines. **Actifs** : comptes, PII, commandes, devis, tarifs, stocks, secrets prestataires, disponibilité du commerce.

| Scénario | Surface | Niveau provisoire | Contrôle existant | Contrôle manquant / preuve exigée |
|---|---|---|---|---|
| BOLA / IDOR inter-tenant | API REST/RPC | Critique | RLS, tuples `store_id`, SECURITY INVOKER pour lecture catalogue | Tests authentifiés croisés, audit complet des fonctions SECURITY DEFINER |
| Enregistrement de commande manipulé | RPC métier | Critique | Prix et stock recalculés côté SQL, idempotence | Tests de concurrence multi-session + résilience aux locks |
| Confirmation frauduleuse de paiement manuel | RPC `confirm_manual_payment` | Élevé | Exige validation humaine explicite et rôle | Double contrôle à définir avec Ahmed, traces d'encaissement réelles |
| DDoS/recherche très coûteuse | Recherches publiques | Élevé | Limites 8 suggestions/48 page, GIN FTS/trgm, longueurs bornées | WAF/rate limit, limites sur requêtes pathologiques, index/plan en staging 100k |
| Injections SQL/XSS | Champs recherche, formulaire | Élevé | SQL paramétré, création DOM via textContent | Tests automatisés payload, revue CSP, URL/HTML et upload |
| Vol de session | navigateur/sessionStorage | Élevé | Jeton Supabase + HTTPS | Stratégie anti-XSS, sessions, expiration, refresh, CSP strict et test réel |
| Fuite de médias non publiés | Storage public | Élevé | ACL écriture; table metadata tenant | Décision d'isoler médias privés/prod et vérification de non-exposition |
| Fausse disponibilité produit | Projection catalogue | Élevé | Liste publiée, trigger de rafraîchissement | Réconciliation full catalog ↔ produit après import massif, tests de transitions |
| Injection de fichier dangereux | Storage | Moyen/Élevé | MIME whitelist/5Mo | Validation MIME serveur, scan contenu, EXIF, redimensionnement, droits et rétention |
| Compromission supply-chain | CI/CD et modules | Élevé | CI JS/SQL et PR draft | CodeQL, secret scanning, lockfile, signatures, protection de branche, SCA et SBOM |
| Panne ou corruption DB | PostgreSQL | Élevé | Transactionnalité PostgreSQL | Sauvegarde/restauration vérifiée, RPO/RTO contractualisés, PRA |
| Non conformité données | Profil clients/marketing | Élevé | Opt-in explicite stocké | DPA/registre, cookies, droits d'accès/suppression, légaux et politique de conservation |

## Règles d'audit
- Les valeurs `store_id` fournies par un navigateur **ne constituent jamais** une preuve d'autorisation.
- `SECURITY DEFINER` justifie obligatoirement une revue ligne par ligne, limitation d'exécution et `search_path` contrôlé.
- Les fonctions de lecture `chr_catalog_*` sont **SECURITY INVOKER** et appliquent RLS ; toute modification doit conserver cet invariant.
- Le site Lovable n'est pas une infrastructure d'autorité. GitHub et Supabase restent sources métier.
- Les résultats des scanners sont indicatifs. Seuls les tests de pénétration et audits manuels valident les risques complexes.
