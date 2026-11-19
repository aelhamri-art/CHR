# CHR — Campagne de validation 100 000 références

**Attention : la cible 100k n'est pas encore validée en charge.** Ne jamais insérer 100k lignes de test dans la base CHR utilisée par Ahmed. Prévoir un clone de staging anonymisé, une instance isolée et les mêmes ressources/plan PostgreSQL que la production cible.

## Dataset représentatif
- Jeu automatisé : **100 000 SKUs**, **10 000 produits parents × 10 variantes**, **20 catégories**, **100 fournisseurs**, prix et poids variables ; autres distributions à tester séparément.
- Minimum 1 à 3 images réelles de test par produit, leur CDN simulant les caractéristiques médias prévues.
- 2 boutiques distinctes pour confirmer l'isolation RLS. Jeu de tests totalement synthétique, sans PII.
- Distribuer longueurs de titres, accents, références avec tirets, doublons de noms (SKU uniques), termes populaires et termes rares.

## Parcours
- 60% lecture catalogue (première page + curseurs >20 pages).
- 25% recherche par SKU, nom, catégorie, faute légère ; 2-80 caractères et variantes d'accents.
- 10% fiches produit multi-variantes.
- 5% panier de 1 à 25 produits, dont référence supprimée ou dépubliée entre deux étapes.
- Réaliser 3 jeux : faible charge, charge nominale, pointe à définir selon trafic commercial prévisionnel; ajouter tests de connexion et devis à profils authentifiés.

## Cibles préliminaires à ajuster selon budget d'infrastructure
- Au 75e percentile sur **de vrais terminaux mobiles** : LCP <= 2,5 s, INP <= 200 ms, CLS <= 0,1. Ce sont des objectifs de mesure, pas des garanties.
- En environnement staging équivalent production : recherche catalogue et suggestions p95 < 500 ms à charge nominale, erreurs < 0,5 % (à réviser après accord des SLO et capacité réservée).
- Aucun doublon de commande ou devis sous double tap / rejeu webhook. Aucun prix déterminé par le navigateur.
- Aucune fuite de données inter-tenant sous concurrence.

## Preuves à produire
- EXPLAIN (ANALYZE, BUFFERS) sur recherche, pagination nom, prix bas/haut et détails, sous 100k vraies données; p95/p99, CPU, IO, locks, connexions, index.
- Tableaux des erreurs et latences par endpoint, navigateur/mobile, cache chaud/froid.
- Plan du scénario, matériel, région, durée, échantillonnage, niveaux de charge, commit GitHub, version DB et migrations.
- Décision GO/NO-GO signée par responsable produit, responsable technique, auditeur sécurité.

## Interdit
- Ne pas inférer la capacité depuis un EXPLAIN sur une seule référence de production.
- Ne pas appeler les 55 lignes du test fonctionnel « une preuve 100k ».
- Ne pas faire de stress test sur la production sans fenêtre, sauvegarde et autorisation explicite.


## Procédure exécutable — staging ISOLÉ uniquement

Le script refuse explicitement l'URL de production Supabase CHR
\`dkisxdquvryoddpphgeg\`, et exige une confirmation explicite. Ne pas l'exécuter
sur une branche de production, ni y coller les identifiants d'un vrai client.

1. Préparer un projet Supabase ou une branche de développement **séparée**
   (un coût Supabase peut s'appliquer, à autoriser avant création). Appliquer
   les migrations de CHR sur staging avant d'importer les fixtures.
2. Créer une boutique de **test** dans ce staging, et un compte gestionnaire
   de **test** avec permissions. Garder la boutique \`published=false\`.
3. Dans un shell local (jamais dans un commit ou un ticket), fournir :
   
   \`\`\`bash
   export STAGING_URL='https://<staging-ref>.supabase.co'
   export STAGING_ANON_KEY='<staging-public-key>'
   export STAGING_STORE_ID='<uuid-boutique-test>'
   export STAGING_SLUG='chr-staging'
   export STAGING_EMAIL='<test-admin-email>'
   export STAGING_PASSWORD='<test-admin-password>'
   export ALLOW_CHR_STAGING_SEED='I_UNDERSTAND_STAGING_ONLY'
   node benchmarks/100k/seed-staging.mjs
   \`\`\`

   Le script vérifie que la boutique staging n'est pas publiée ; il met en
   place les paramètres non publiés s'ils sont absents, charge les produits
   par lots transactionnels de 300 et mesure les totaux via les privilèges
   réels du gestionnaire. Le re-lancement de chaque lot utilise une clé
   déterministe, pas un nouvel identifiant aléatoire.

4. Lancer la charge via \`k6\` en réutilisant les mêmes variables staging :
   
   \`\`\`bash
   export ALLOW_CHR_STAGING_LOAD='YES'
   k6 run benchmarks/100k/catalog.k6.js
   \`\`\`

   Le scénario utilise les droits du compte staging et refuse le lancement
   si la boutique est vide ou si la cible est la production. Tester en
   plus un flux \`anon\` via \`STAGING_PUBLIC=YES\` **uniquement** dans une
   boutique de staging publiée volontairement ; ne pas publier CHR pour
   contourner cette exigence.

5. Exporter rapport \`k6\`, plans \`EXPLAIN (ANALYZE, BUFFERS)\` de chaque
   requête, métriques PostgreSQL, nombre de lignes et configuration
   machine. Versionner dans un rapport d'audit sans jetons ni PII.

**IMPORTANT : ce protocole est prêt, mais il n'a pas encore été exécuté
sur 100 000 références dans un staging indépendant. La capacité 100K n'est
donc pas certifiée.** Les tests réalisés sur la base CHR portent uniquement
sur de petits jeux transactionnels annulés.
