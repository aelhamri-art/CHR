# CHR — Mandat produit : expérience client commerciale premium
Date : 2026-11-17
Statut : cahier des charges technique et expérience, non implémenté.
Code maître : GitHub CHR. Données : Supabase CHR. Aucun Lovable, Medusa ni Shopify. Marque commerciale affichée : celle d'Ahmed (à vérifier sur ses vrais supports), et non AXIUM Commerce OS côté clients.

## Vision mesurable
Créer une expérience de commerce B2B pour matériel CHR qui transforme un premier visiteur en prospect qualifié ou acheteur, puis en client récurrent. La DA doit générer une impression de maîtrise technique et de fiabilité, sans fausses preuves commerciales ni effets lourds qui pénalisent l'utilisateur. Priorité : recherche produit et achat/devis avec minimum de friction.

## Architecture recommandée
- **Storefront** : React/TypeScript, Next.js App Router ou framework SSR équivalent validé au moment de la mise en œuvre ; pages vitrines et catégories pré-rendues/SSR, accès aux données catalogue publiques via API contrôlée et cache.
- **Admin** : application préexistante, isolée sur route/sous-domaine non public ; mêmes tables métier mais services d'accès distincts.
- **Supabase** : Auth, PostgreSQL, Storage produit. Isolation RLS par magasin et utilisateur.
- **Paiements** : Stripe (ou PSP effectivement choisi par Ahmed), côté serveur uniquement. Confirmation par webhooks signés ; Checkout/PaymentIntents et SetupIntents selon cas, cartes *tokenisées chez le PSP*. Pas de PAN ni CVV en base.
- **Actions métier** : les calculs de prix, TVA, disponibilité et port sont autoritaires en base/serveur ; le panier client ne peut pas envoyer des montants libres.
- **Visuels** : médias réellement possédés ou licenciés, vidéos compressées, rendus produit vérifiés. Aucun produit, avis, stock ou badge de confiance inventé. Pas d'image hébergée sur une URL tierce non autorisée comme asset de production.
- **SEO** : URLs stables, métadonnées uniques, OG, sitemap, robots, données structurées Product/Offer à partir d'informations réelles, canonicals, performance mobile.

## IA/DA et signature visuelle
Site de marque, pas template e-commerce générique. Direction à définir depuis les vrais assets d'Ahmed ; traitement photographique cohérent, grandes images éditoriales, détails de matières et usages réels, navigation contextuelle. Couleurs et typographies de marque propres. Motion léger (reveal, profondeur, transitions, micro-feedback) avec prefers-reduced-motion, lazy-loading, stratégie d'autoplay limitée, pas de hijacking du scroll, pas de smooth scroll forcé. Cible de performance mobile mesurée : LCP <=2,5s, CLS <=0,1, INP <=200ms au 75e percentile si environnement réaliste ; l'objectif n'est pas une garantie avant test.

## Parcours et écrans — registre initial
STO-001 Accueil : hero de promesse précise, CTA catégories/produits/devis, preuve réelle, catalogue recommandé, services et réassurance.
STO-002 Pages de catégorie : sous-catégories, comparaison, filtres utiles au CHR, liste/grille, tri, disponibilité, marques et SEO.
STO-003 Recherche instantanée : autosuggest, correction orthographique, alias, filtres techniques et raccourcis clavier.
STO-004 Produit : galerie photo/vidéo nette, zoom, données vérifiées, dimensions, compatibilités, poids, alimentation, variantes, stock affiché selon politique, délai, TVA HT/TTC, garanties vérifiées, livraison calculée, CTA panier/devis.
STO-005 Comparateur : 2-4 références, différences techniques et prix.
STO-006 Panier : quantités, suppression/undo, devise EUR, frais calculés serveur, persistance adaptée, prévention du double-clic et ventes impossibles.
STO-007 Checkout : invité ou connecté selon validation commerciale, adresses B2B, raison sociale, TVA si nécessaire, port, récapitulatif, consentement conditions; PSP et étape d'auth forte.
STO-008 Compte : inscription, connexion, confirmation e-mail, récupération, éventuellement passkeys/social auth selon fournisseur/configuration.
STO-009 Profil : informations personnelles, entreprise, contacts, adresses de facturation/livraison, consentements, export et suppression légalement admissible.
STO-010 Moyens de paiement : voir/ajouter/supprimer des références PSP liées au compte et permission explicite, aucun stockage de numéro de carte/CVV.
STO-011 Historique : commandes, statut, détail, factures si facturation mise en place, réachat simple.
STO-012 Wishlist et projet : favoris, listes d'équipement et demandes de devis pour achats professionnels complexes.
STO-013 Contact et SAV : canaux vérifiés, FAQ utile, formulaire structuré, relais WhatsApp uniquement lorsque contractualisé, réponse sans promesse inventée.
STO-014 Pages de confiance : livraison, conditions, retours, garanties, mentions légales, politique de confidentialité, cookies/consentement, accessibilité.
STO-015 Landing pages d'acquisition : campagnes dédiées à chaque intention CHR, promesse unique, preuve réelle, CTA spécifique et attribution mesurable.
STO-016 Mobile-app feel : nav par usage/pouce, sticky buy bar sans masquer le contenu, zones tactiles >=44px, aucun double scroll, feedback perceptible, erreurs compréhensibles.
STO-017 Mesure : funnel impression produit > recherche > fiche > panier > checkout > paiement ou devis, consentement applicable, performance et événements de friction.
STO-018 États négatifs : zéro résultat, rupture, échec paiement, adresse hors zone, changement de prix, hors-ligne, reconnexion, retour arrière sans perte du panier.
STO-019 Accessibilité et locales : WCAG AA ciblé, contraste, focus visible, lecteur d'écran, clavier, prefers-reduced-motion, i18n seulement si commerce international validé.
STO-020 Référencement et indexation : sitemap, Product/Offer à partir de données confirmées, pas d'exposition de données d'admin.

## Fondations Supabase à construire avant mise en vente
- **Public catalog API** : projection publique sûre par boutique, seulement produits actifs/publiés, prix affichables, images publiques, éventuelle disponibilité agrégée. Ne jamais exposer coûts d'achat, données clients, métadonnées internes ou écriture admin.
- **Customer identity** : comptes clients rattachés à auth.users distincts des rôles admin, profil/adresses et entreprise autorisée, avec RLS tests croisés.
- **Carts** : ligne, variant_id, quantité, boutique, expiration, provenance, identifiant anonyme ou utilisateur; prix recalculés serveur.
- **Checkout** : validation atomique panier/stock/TVA/livraison, réservation et expiration, anti-survente, montants exacts, idempotence. Un seul paiement donne une seule commande.
- **Payments** : client PSP et payment_method_id tokenisé, consentement stockage, client_secret temporaire, webhooks vérifiés et rejouables; état paiement jamais déterminé par succès navigateur.
- **Orders** : séparer commande client de la commande créée par administrateur, droits lecture client limités à ses achats; adresse/PII protégées.
- **Returns** : demande SAV/retour soumis aux règles commerciales réellement publiées, jamais fausse promesse.
- **Performance/backup** : cache et invalidation après modification admin, asset pipeline, rollback et observabilité.

## Tests de réception
- Produit ajouté dans AXIUM Commerce OS apparaît dans la bonne catégorie client après publication, et disparaît immédiatement s'il est dépublié.
- Variante, prix, poids et livraison configurés en admin produisent la même vérité dans fiche, panier, checkout et commande.
- Deux utilisateurs/entreprises ne peuvent pas consulter leurs adresses/moyens de paiement/commandes respectifs.
- Rechargement, back, partage de lien, multi-onglet et périphériques mobiles n'effacent pas inopinément le parcours.
- Rejouer webhook / double tap ne crée ni deux paiements ni deux commandes.
- Les cartes enregistrées sont identifiées uniquement par marque, quatre derniers chiffres et token PSP, après consentement ; pas de CVV ou PAN en base.
- QA motion : 60fps visé lorsque possible, faible consommation vidéo, arrêt des animations si préférence utilisateur.
- Cible smartphone 320px à grand écran, axe de défilement unique sur chaque page, zones tactiles et modales testées.
- Aucune donnée fournisseur ou preuve commerciale fictive.

## Dépendances humaines avant production
Marque/logo/nom public d'Ahmed, catalogue complet et photographies/vidéos dont les droits sont établis, promesses SAV/garantie et livraison validées, domaines, mentions légales, PSP (compte pro/KYC), TVA/pays de vente, CGV/confidentialité, règles commerciales B2B. Ne jamais masquer ces dépendances derrière des mocks.

## État des données observé au 17/11/2026
Supabase CHR : 2 boutiques, 1 produit et 1 variante, 1 profil de livraison, mais 0 médias produit, 0 zones/tarifs livraison, 0 taxe, 0 entrepôt, 0 commande. La vente en ligne n'est donc pas prête en l'état.

## Critère GO
Site public et apps clients ne sont pas « terminés » avant (1) tests E2E réels, (2) sécurité/RLS, (3) paiement sandbox et webhook, (4) livraison/calcul taxes autoritaires, (5) vrais assets, (6) audit performance et accessibilité, (7) validation commerciale et juridique d'Ahmed.
