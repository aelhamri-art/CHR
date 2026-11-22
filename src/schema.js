/* Registre de schémas de formulaires. Une seule source pour CRUD et validations côté interface. */
export const field=(name,label,type='text',extra={})=>({name,label,type,...extra});
const status=(name='status',items=['draft','active','archived'])=>field(name,'État','select',{options:items.map(x=>({value:x,label:({draft:'Brouillon',active:'Actif',archived:'Archivé',disabled:'Désactivé',open:'Ouvert',completed:'Terminé',cancelled:'Annulé'})[x]||x}))});
export const MODULES={
 products:{
  label:'Produits',section:'Catalogue',description:'Fiches, statuts, fournisseurs, métadonnées et visibilité.',
  columns:['title','status','vendor','product_type','updated_at'],
  fields:[
   field('title','Nom du produit','text',{required:true,max:180}),
   field('handle','Identifiant URL','slug',{required:true,max:180}),
   field('description','Description','textarea'),
   status(),field('vendor','Fournisseur'),field('product_type','Type / catégorie'),
   field('tags','Tags séparés par virgules','list'),
   field('metadata','Métadonnées (JSON)','json')
  ],
  onDelete:'archive'
 },
 product_variants:{
  label:'Variantes & SKU',section:'Catalogue',description:'Options et prix des variantes de produits.',
  columns:['sku','title','product_id','price_minor','weight_grams'],
  fields:[
   field('product_id','Produit parent','relation',{required:true,table:'products',display:'title'}),
   field('title','Variante','text',{required:true}),
   field('sku','Référence SKU','text'),
   field('barcode','Code-barres'),
   field('options','Options (JSON)','json'),
   field('price_minor','Prix HT (€)','money',{required:true}),
   field('compare_at_minor','Prix comparé (€)','money'),
   field('cost_minor',"Coût d'achat (€)",'money'),
   field('weight_grams','Poids (grammes)','integer',{min:0}),
   field('requires_shipping','Produit physique','boolean'),
   field('taxable','Taxable','boolean')
  ]
 },
 collections:{
  label:'Collections',section:'Catalogue',description:'Regroupements manuels et conditions de classement.',
  columns:['title','type','status','handle','updated_at'],
  fields:[
   field('title','Nom','text',{required:true}),field('handle','Identifiant URL (généré si vide)','slug'),
   field('description','Description','textarea'),
   field('type','Type','select',{options:[{value:'manual',label:'Manuelle'},{value:'automated',label:'Automatique (moteur non activé)'}]}),
   field('rule_logic','Logique','select',{options:[{value:'all',label:'Toutes les règles'},{value:'any',label:'Au moins une règle'}]}),
   field('rules','Conditions (JSON)','json_array'),status()
  ]
 },
 collection_products:{
  label:'Produits dans collections',section:'Catalogue',description:'Associations pour les collections manuelles.',
  columns:['collection_id','product_id','position','created_at'],
  fields:[
   field('collection_id','Collection','relation',{table:'collections',display:'title',required:true}),
   field('product_id','Produit','relation',{table:'products',display:'title',required:true}),
   field('position',"Ordre d'affichage",'integer',{min:0})
  ],key:'composite',onDelete:'delete'
 },
 locations:{
  label:'Emplacements',section:'Stock',description:'Dépôts, entrepôts et sites de préparation.',
  columns:['name','active','address','created_at'],
  fields:[field('name','Nom','text',{required:true}),field('address','Adresse (JSON)','json'),field('active','Actif','boolean')]
 },
 tax_rules:{
  label:'Règles fiscales',section:'Finance',description:'TVA explicite selon pays. La création de commande exige une règle active.',
  columns:['country','name','rate_basis_points','tax_shipping','active'],
  fields:[
   field('country','Pays ISO','text',{required:true,max:2}),
   field('name','Intitulé','text',{required:true}),
   field('rate_basis_points','TVA en points de base (2000 = 20 %)','integer',{min:0,required:true}),
   field('tax_shipping','Taxer la livraison','boolean'),
   field('active','Active','boolean')
  ]
 },
 inventory_levels:{
  label:'Niveaux de stock',section:'Stock',description:'Quantité physique et quantité réservée par variante et entrepôt.',
  columns:['variant_id','location_id','on_hand','reserved','updated_at'],fields:[],readOnly:true
 },
 inventory_movements:{
  label:'Mouvements de stock',section:'Stock',description:'Historique immuable des ajustements et opérations.',
  columns:['inventory_level_id','delta','reason','created_at'],fields:[],readOnly:true
 },
 customers:{
  label:'Clients B2B',section:'Commercial',description:'Identités, entreprises, consentements et coordonnées.',
  columns:['company','first_name','last_name','email','phone'],
  fields:[
   field('company','Entreprise'),field('first_name','Prénom'),field('last_name','Nom'),
   field('email','Email','email'),field('phone','Téléphone'),
   field('addresses','Adresses (JSON)','json_array'),
   field('marketing_consent','Consentement marketing explicite','boolean'),
   field('notes','Notes privées','textarea')
  ],onDelete:'delete'
 },
 orders:{
  label:'Commandes',section:'Commercial',description:'Commandes réelles, leurs états et leurs montants figés.',
  columns:['order_number','status','payment_status','fulfillment_status','total_minor','created_at'],
  fields:[],readOnly:true
 },
 order_lines:{
  label:'Lignes de commande',section:'Commercial',description:'Prix, produit et quantité au moment de la validation.',
  columns:['order_id','sku','product_title','quantity','unit_price_minor'],
  fields:[],readOnly:true
 },
 payment_transactions:{
  label:'Transactions',section:'Finance',description:'Événements de prestataires de paiement (lecture seule).',
  columns:['order_id','provider','kind','status','amount_minor','created_at'],fields:[],readOnly:true
 },
 refunds:{
  label:'Remboursements',section:'Finance',description:'Remboursements réellement exécutés par prestataire.',
  columns:['order_id','amount_minor','status','reason','created_at'],fields:[],readOnly:true
 },
 shipping_profiles:{
  label:'Profils de livraison',section:'Livraison',description:'Modes de livraison distincts selon le catalogue.',
  columns:['name','is_general','created_at'],
  fields:[field('name','Nom du profil','text',{required:true}),field('is_general','Profil général','boolean')]
 },
 shipping_zones:{
  label:'Zones de livraison',section:'Livraison',description:'Destinations et restrictions de codes postaux.',
  columns:['name','profile_id','countries','postal_prefixes'],
  fields:[
   field('profile_id','Profil','relation',{table:'shipping_profiles',display:'name',required:true}),
   field('name','Nom de la zone','text',{required:true}),
   field('countries','Pays ISO (FR,BE...)','upper_list'),
   field('postal_prefixes','Préfixes postaux autorisés','list'),
   field('excluded_postal_prefixes','Préfixes postaux exclus','list')
  ]
 },
 shipping_rates:{
  label:'Tarifs de livraison',section:'Livraison',description:'Règles par poids, valeur, destination et catégorie.',
  columns:['name','mode','amount_minor','zone_id','enabled'],
  fields:[
   field('zone_id','Zone','relation',{table:'shipping_zones',display:'name',required:true}),
   field('name','Nom du tarif','text',{required:true}),
   field('mode','Calcul','select',{options:[{value:'flat',label:'Fixe'},{value:'weight',label:'Poids'},{value:'order_value',label:'Montant commande'},{value:'carrier',label:'Transporteur (connecteur nécessaire)'}]}),
   field('amount_minor','Tarif (€)','money',{required:true}),
   field('min_weight_grams','Poids minimum (g)','integer'),
   field('max_weight_grams','Poids maximum (g)','integer'),
   field('min_order_minor','Sous-total minimum (€)','money'),
   field('max_order_minor','Sous-total maximum (€)','money'),
   field('enabled','Actif','boolean'),
   field('metadata','Options (JSON)','json')
  ]
 },
 discounts:{
  label:'Réductions',section:'Marketing',description:'Codes promotionnels, seuils et règles de cumul.',
  columns:['name','code','type','value','status','valid_until'],
  fields:[
   field('name','Nom','text',{required:true}),field('code','Code'),
   field('type','Type','select',{options:[{value:'fixed',label:'Montant fixe'},{value:'percentage',label:'Pourcentage en base 100 (ex. 1500 = 15 %) '},{value:'free_shipping',label:'Livraison gratuite'}]}),
   field('value','Valeur entière (centimes ou points de base)','integer',{min:0}),
   field('usage_limit','Nombre maximum d’utilisations','integer'),
   field('valid_from','Début (ISO8601)','datetime'),field('valid_until','Fin (ISO8601)','datetime'),
   status('status',['draft','active','disabled']),
   field('rules','Règles (JSON)','json')
  ]
 },
 audit_events:{
  label:'Historique',section:'Sécurité',description:'Journal des modifications réelles, horodatées et attribuées.',
  columns:['created_at','actor_type','entity_type','action','entity_id'],fields:[],readOnly:true
 },
 action_requests:{
  label:'Actions Aximus',section:'Sécurité',description:'Contrats et demandes prêts pour une intégration future. Agent non actif.',
  columns:['action_key','status','created_at','executed_at'],fields:[],readOnly:true
 }
};
export const GROUPS=[
 {label:'Vue générale',items:[['dashboard','Tableau de bord','layout-dashboard'],['orders','Commandes','shopping-bag'],['sales_quotes','Devis commerciaux','file-text'],['products','Produits','package'],['product_variants','Variantes','layers'],['collections','Collections','folder'],['collection_products','Associations','link'],['media','Médias produits','image'],['import','Importer CSV','upload']]},
 {label:'Exploitation',items:[['locations','Entrepôts','warehouse'],['inventory_levels','Stocks','boxes'],['inventory_movements','Mouvements','arrow-left-right'],['customers','Clients','users'],['shipping_profiles','Profils livraison','truck'],['shipping_zones','Zones','map'],['shipping_rates','Tarifs livraison','scale'],['tax_rules','Taxes et TVA','receipt']]},
 {label:'Commerce',items:[['discounts','Réductions','badge-percent'],['payment_transactions','Paiements','credit-card'],['refunds','Remboursements','receipt'],['order_lines','Lignes de commande','list'],['audit_events','Historique','shield-check']]},
 {label:'Système',items:[['storefront','Boutique client','globe'],['settings','Paramètres','settings'],['business_policies','Règles métier','sliders-horizontal'],['action_requests','Intégration Aximus','sparkles']]}
];
export const readonlyModules=Object.keys(MODULES).filter(k=>MODULES[k].readOnly);
