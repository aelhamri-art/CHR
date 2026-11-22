# AXIUM OS CHR — Contrats d'intégration et critères d'activation
**Statut : conception et points de raccordement ; ni Stripe ni AXIMUS ne sont actifs.**
Cette note sert de contrat pour un développeur senior externe. Elle ne remplace ni l'intégration en environnement sandbox, ni la revue de sécurité.

## Règle d'architecture : l'interface n'est jamais autorité

UI (Lovable / AXIUM OS) → API métier authentifiée (Supabase, RLS + contrôles de capacité)
→ transactions PostgreSQL / événements métiers → adaptateur du prestataire.
Tous les changements de prix, paiements, commandes, réservations et états à risque
sont validés par le serveur ; le client et l'agent ne peuvent pas se déclarer propriétaires.

## Port Stripe / prestataire bancaire

### Opérations et effets attendus
1. \`CreateCheckout(orderId, storeId, idempotencyKey)\` — reçoit uniquement des IDs et une clé
   d'idempotence ; **le prix et la devise sont chargés depuis la commande serveur**.
2. \`CancelCheckout\` — annulation en respectant le statut PSP réel.
3. \`VerifyWebhook(rawBody, signature, endpointSecret)\` — vérification cryptographique
   **avant toute action** ; ne jamais faire confiance à un \`payment_status\` côté navigateur.
4. \`RecordVerifiedPaymentEvent\` — table append-only, unique \`(provider,event_id)\` et
   traitement idempotent ; montant, devise, entreprise et commande doivent correspondre.
5. \`RequestRefund\` — stratégie de compensation et rapprochement ; n'actualise pas
   la commande en \`refunded\` tant que le PSP n'a pas confirmé l'opération.
6. Gestion des cas asynchrones : expiration, authentification 3DS, échec, double webhook,
   événements hors ordre, débit après annulation, remboursement partiel et réconciliation.

### Critère d'activation
- Clés Stripe présentes seulement dans Supabase secrets / Vault, jamais dans GitHub ou JS.
- Connecteur Edge Function ou backend isolé, webhooks signés, endpoint protégé contre
  les replays, journalisation sans informations bancaires sensibles.
- Tests sandbox avec paiement accepté, refusé, doublé, retardé et remboursé.
- Réconciliation avec le registre des commandes sous concurrence ; CI + preuve manuelle.
- Le paiement manuel existant reste distinct et n'est jamais présenté comme une transaction Stripe.

## Port AXIMUS

| Capability ID | Mode | Validation |
| --- | --- | --- |
| \`catalog.search\` | lecture | Autorisation tenant en base |
| \`inventory.read\` | lecture | Autorisation tenant en base |
| \`quotes.draft\` | préparation | Brouillon dans le périmètre du collaborateur |
| \`quotes.propose\` | écriture sensible | Validation humaine requise |
| \`orders.draft\` | préparation | Pas de paiement ou stock fictif |
| \`orders.commit\` | écriture sensible | Validation explicite, prix calculés serveur |
| \`inventory.adjust\` | écriture sensible | Validation explicite, motif et audit |
| \`payments.confirm\` | écriture financière | Jamais automatique, autorisation renforcée |
| \`refunds.issue\` | écriture financière | Jamais automatique, PSP et approbation |

L'agent sera un **principal distinct**, avec des outils métier versionnés,
un \`store_id\` résolu par le backend, des permissions de type least privilege,
des durées de session limitées, des quotas, une validation humaine par opération
sensible et un journal \`action_requests\`/événements horodatés. Aucune
exécution libre de SQL, aucune clé service_role dans le contexte d'un LLM.

### Critère d'activation
- Registre d'outils et schéma d'arguments stables, versionnés et testés.
- Une demande d'action n'est pas une exécution ; elle comporte \`pending → approved/rejected → executed/failed\`.
- Une approbation est limitée à l'action et au montant précis, non réutilisable.
- Démonstration IDOR multi-entreprise, injections de prompt, rejouement, faux
  consentement, escalade de privilèges et annulation.
- Possibilité de désactiver l'agent instantanément par boutique et type d'action.

## Autres ports : livraison et notifications
- Transporteur : \`quote → create_label → track → cancel\` avec identifiants de suivi,
  réponses asynchrones, multi-colis, poids volumétrique et échecs de transport.
- Notification : email/SMS/WhatsApp avec consentements, templates versionnés,
  suivi des tentatives, relances idempotentes et fréquence ajustable.
- Facturation : émission légale, avoirs, TVA et numérotation non modifiable avec
  provider métier adapté. Une facture émise ne se réécrit pas silencieusement.

## Risques et règles de déploiement
Ne pas déclarer une intégration « prête à activer » avant l'existence de son
adaptateur exécutable, d'un environnement sandbox, d'un test webhook et de sa
documentation d'installation. Les interfaces définies ici sont des CONTRATS,
pas des services déjà opérationnels.

État actuel : PR #6 = devis/commandes/prix/stocks P0 ; Stripe, AXIMUS, transporteur,
facturation et notifications restent des périmètres à développer et valider.
