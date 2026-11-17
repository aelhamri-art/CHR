# CHR — Rapport de réalisation Storefront, 17 novembre 2026

## Configuration effective
- GitHub : branche `feat/chr-storefront-experience`, PR #3, branche parent `feat/chr-admin-github-native`.
- Supabase : projet `dkisxdquvryoddpphgeg` (`CHR`), base unique pour administration et client.
- Architecture MVP : ES Modules JavaScript natifs, CSS responsive, sans dépendance à Shopify, Medusa, Lovable ou moteur tiers.
- Environnements : admin à `/`; boutique client à `/storefront/` sur un serveur HTTP statique, sans déploiement de domaine public.
- Configuration de boutique : slug `chr` dans `storefront/config.js`. Il existe également un second store `chr33` ; ne jamais les fusionner implicitement.
- Publication `chr` : désactivée par défaut, documents légaux et médias vérifiés obligatoires.

## Parcours codés
- Accueil éditorial avec hiérarchie commerciale et mouvement non bloquant, hero public configurable depuis l'admin.
- Catalogue projeté publiquement (uniquement produits actifs après publication), recherche, catégories, tri, pages produits, variantes.
- Panier persistant local, contrôle de quantité, prix affichés en centimes depuis projection sûre. Jamais de total final de paiement calculé uniquement côté navigateur.
- Auth email/mot de passe, inscription et récupération via Supabase Auth; session client distincte de celle de l'admin.
- Profil client B2B, consentement opt-in, adresses, favoris, panier enregistré et historique de demandes de devis.
- Demande de devis via fonction SQL validant à nouveau les références/prix côté serveur, avec limite de volume et clé d'idempotence.
- Back-office : identité, publication, contenus légaux, média hero et suivi du statut de devis.

## Contrôles techniques exécutés
- Test SQL transactionnel avec ROLLBACK : produit actif + variante apparait dans projection ; archiver le produit retire la projection.
- RLS active sur 32 tables `public`. Les tables clients et les demandes ne sont pas ouvertes à `anon`.
- Seule la projection du catalogue et les paramètres de boutique publiés sont lisibles anonymement ; données internes absentes de la projection.
- Contrôle SQL de restriction de publication : CGV, confidentialité, mentions légales, contact et photographie approuvée obligatoires.
- CI GitHub native : 13 tests unitaires réussis, syntaxe et filtrage des références à clés serveur.
- QA navigateur Chromium : contrôle de navigation, responsive, accessibilité de base, captures, test mobile de débordement horizontal. Voir l'historique GitHub Actions pour la version exacte.

## Limitations bloquantes
- Aucun domaine client ni hébergement production connecté.
- **Pas de paiement carte en ligne ni de cartes enregistrées.** Le compte PSP, la configuration Stripe, le consentement et les webhooks restent à intégrer/tester. Aucun PAN/CVV stocké.
- Les photos réelles et vidéos clients sont absentes ; l'interface affiche des compositions graphiques CSS et un mécanisme de chargement des vraies photos Supabase une fois approuvées.
- Boutique `chr` non publiée : le public ne voit pas les produits, afin de ne pas exposer les tests ou données non approuvées.
- Le routage V1 utilise des URL hash; SSR/SEO technique avancé, sitemap produit et données structurées doivent être implémentés avant une mise en vente internationale.
- Aucun test authentifié avec de vrais comptes clients, session multi-devices, données de paiements ou commande client réelle n'a été réalisé.
- Comparateur avancé, onboarding B2B sophistiqué, suivi de commande client, SAV, facturation, e-mails transactionnels et retours non terminés.
- Les contrôles de sécurité Supabase continuent d'afficher des avis pour les fonctions privilégiées et la protection des mots de passe compromis (intervention humaine + revue).

## Prérequis humains pour le GO
1. Valider nom commercial, logo, palette, typographie et mentions publiques d'Ahmed.
2. Importer le catalogue réel, les photos/vidéos et documents techniques avec droits d'usage.
3. Fournir e-mail de contact, coordonnées, CGV, confidentialité, mentions légales approuvées.
4. Configurer la boutique correcte (`chr` vs `chr33`) et la publication depuis l'admin.
5. Connecter compte bancaire/PSP conforme, réaliser vérification KYC et tests de webhooks et tokenisation.
6. Valider TVA, livraison, retours, garanties, SAV et documentation d'achat.
7. Configurer domaine HTTPS, DNS, Auth et protections anti-bots avant ouverture.
8. Exécuter tests E2E authentifiés, sécurité IDOR/RLS, charge, accessibilité, SEO et sauvegarde/restauration.

## Décision
**NO-GO PRODUCTION.** Première expérience codée et testée sur des parcours sans données réelles, mais pas une livraison commerciale complète ni un niveau top 1 % démontré. PR conservée en brouillon.
