/* Administration de la vitrine CHR directement depuis GitHub + Supabase. */
import * as api from './api.js';
const E=(tag,attrs={},...children)=>{
 const node=document.createElement(tag);
 for(const [key,value] of Object.entries(attrs)){
  if(key==='className')node.className=value;
  else if(key==='onSubmit')node.addEventListener('submit',value);
  else if(key==='onClick')node.addEventListener('click',value);
  else if(key==='checked')node.checked=!!value;
  else if(key==='selected')node.selected=!!value;
  else if(key==='disabled')node.disabled=!!value;
  else if(key==='value')node.value=value??'';
  else if(key==='type')node.type=value;
  else if(key==='required')node.required=!!value;
  else node.setAttribute(key,String(value));
 }
 children.flat().forEach(c=>{if(c!==null&&c!==undefined)node.append(c instanceof Node?c:document.createTextNode(String(c)));});
 return node;
};
const field=(label,control)=>E('label',{className:'field'},E('span',{},label),control);
function input(name,value='',type='text'){return E('input',{name,type,value});}
function area(name,value='',rows=7){return E('textarea',{name,rows},value||'');}
function section(title,description,fields){return E('section',{className:'panel'},E('h2',{},title),E('p',{className:'muted'},description),E('div',{className:'form-grid'},...fields));}
function settingsFields(current){
 const slug=input('public_slug',current.public_slug||'chr');slug.required=true;
 const brand=input('brand_name',current.brand_name||'CHR');brand.required=true;
 const eyebrow=input('eyebrow',current.eyebrow||'');
 const headline=input('headline',current.headline||'');headline.required=true;
 const subline=area('subline',current.subline||'',3);
 const contact=input('contact_email',current.contact_email||'','email');
 const image=input('hero_image_path',current.hero_image_path||'');
 const legal=area('legal_notice',current.legal_notice||'');
 const privacy=area('privacy_policy',current.privacy_policy||'');
 const terms=area('terms_of_sale',current.terms_of_sale||'');
 const publish=E('input',{type:'checkbox',name:'published',checked:!!current.published});
 return {slug,brand,eyebrow,headline,subline,contact,image,legal,privacy,terms,publish};
}
export async function storefrontAdminPage(storeId,onSaved,notify,storeSlug='chr'){
 const [data,products,media,quotes]=await Promise.all([
  api.list('storefront_settings',storeId),
  api.list('products',storeId),
  api.list('product_media',storeId),
  api.list('storefront_quotes',storeId).catch(()=>[])
 ]);
 const current=data[0]||{public_slug:storeSlug,brand_name:'CHR',published:false};
 const f=settingsFields(current);
 const form=E('form',{className:'storefront-config'});
 const save=E('button',{type:'submit',className:'btn accent'},current.published?'Enregistrer et actualiser':'Enregistrer le brouillon');
 const legalStatus=E('div',{className:'notice-inline'},
 'Publication bloquée sans email officiel, documents juridiques présents (minimum technique : 100 caractères chacun, soumis à revue), et produit actif photographié.');
 const sections=[
  section('Identité publique','Ces informations apparaissent sur le site client. Ne pas utiliser les éléments graphiques d’AXIUM Commerce OS comme marque publique sans accord.',
  [field('Adresse courte',f.slug),field('Marque affichée',f.brand),field('Sur-titre',f.eyebrow),field('Promesse principale',f.headline),field('Argumentaire',f.subline),field('E-mail de contact',f.contact),field('Image hero (chemin de fichier approuvé)',f.image)]),
  section('Documents obligatoires','Contenus rédigés et approuvés par Ahmed ou son conseil. Aucun texte juridique fictif ne doit être publié.',
  [field('Mentions légales',f.legal),field('Politique de confidentialité',f.privacy),field('Conditions générales de vente',f.terms)]),
  section('Publication','Le backend refuse toute publication ne satisfaisant pas aux prérequis.',
  [E('label',{className:'field check-field'},E('span',{},'Autoriser la boutique publique'),f.publish)])
 ];
 form.append(...sections,legalStatus,E('div',{className:'page-actions'},save));
 form.addEventListener('submit',async event=>{
  event.preventDefault();save.disabled=true;
  const values={
   public_slug:f.slug.value.trim().toLowerCase(),
   brand_name:f.brand.value.trim(),eyebrow:f.eyebrow.value.trim(),
   headline:f.headline.value.trim(),subline:f.subline.value.trim(),
   contact_email:f.contact.value.trim()||null,hero_image_path:f.image.value.trim()||null,
   legal_notice:f.legal.value.trim()||null,privacy_policy:f.privacy.value.trim()||null,
   terms_of_sale:f.terms.value.trim()||null,published:f.publish.checked
  };
  try{const saved=await api.saveStorefrontSettings(storeId,values);
   notify(saved.published?'Boutique publiée.':'Brouillon de la boutique enregistré.','success');
   await onSaved();
  }catch(error){notify(error.message,'error');}
  finally{save.disabled=false;}
 });
 const pending=quotes.filter(q=>q.status!=='closed');
 const requests=E('section',{className:'panel'},
 E('h2',{},'Demandes de devis reçues'),
 pending.length?E('div',{className:'table-wrap'},
 E('table',{className:'data-table'},E('thead',{},E('tr',{},...['Date','Contact','Entreprise','Estimation HT','État','Action'].map(x=>E('th',{},x)))),
 E('tbody',{},...pending.map(q=>{
  const select=E('select',{},...['new','reviewing','replied','closed'].map(s=>
   E('option',{value:s,selected:s===q.status},({new:'Nouvelle',reviewing:'En cours',replied:'Réponse envoyée',closed:'Clôturée'})[s])));
  return E('tr',{},E('td',{},new Date(q.created_at).toLocaleDateString('fr-FR')),
   E('td',{},q.contact_email),E('td',{},q.company_name||'—'),
   E('td',{},(Number(q.estimate_minor)/100).toLocaleString('fr-FR',{style:'currency',currency:'EUR'})),
   E('td',{},select),E('td',{},E('button',{type:'button',className:'btn',onClick:async()=>{
    try{await api.update('storefront_quotes',q.id,storeId,{status:select.value});notify('Demande mise à jour.','success');await onSaved();}
    catch(error){notify(error.message,'error');}
   }},'Actualiser')));
 })))):E('p',{className:'muted'},'Aucune demande reçue.'));
 const page=E('div',{},
 E('div',{className:'page-header'},E('div',{},E('div',{className:'eyebrow'},'ADMINISTRATION / SITE CLIENT'),
 E('h1',{},'Boutique CHR'),E('p',{className:'lead'},'Identité, textes, publication et devis client — même Supabase que l’administration.')),
 E('div',{className:'page-actions'},
 E('a',{href:'/chr/index.html?preview=1',target:'_blank',rel:'noopener noreferrer',className:'btn'},'Prévisualisation interne'),
 ...(current.published?[E('a',{href:'/chr/index.html',target:'_blank',rel:'noopener noreferrer',className:'btn'},'Voir la boutique publique')]:[]))),
 E('div',{className:'metric-grid'},
 ...[['Statut',current.published?'PUBLIÉE':'BROUILLON'],['Produits',products.length],['Médias',media.length]].map(([title,value])=>
 E('div',{className:'metric'},E('p',{},title),E('strong',{},value)))),
 form,requests);
 return page;
}
