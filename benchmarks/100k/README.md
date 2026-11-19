# CHR — Campagne de validation 100 000 références

**Attention : la cible 100k n'est pas encore validée en charge.** Ne jamais insérer 100k lignes de test dans la base CHR utilisée par Ahmed. Prévoir un clone de staging anonymisé, une instance isolée et les mêmes ressources/plan PostgreSQL que la production cible.

## Dataset représentatif
- 100 000 SKUs minimum, plusieurs milliers de produits parents, 1 à 20 variantes par produit, 20 catégories, 100 fournisseurs, prix divers.
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
