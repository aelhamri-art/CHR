/** AXIUM OS CHR — server-verified release readiness. No simulated success. */
import * as api from './api.js';
const E=(name,attrs={},...children)=>{
 const n=document.createElement(name);
 for(const [k,v] of Object.entries(attrs)){
  if(v===null||v===undefined)continue;
  if(k==='className')n.className=v;
  else if(k==='onClick')n.addEventListener('click',v);
  else if(k==='href')n.href=v;
  else if(k==='type')n.type=v;
  else if(k==='target')n.target=v;
  else n.setAttribute(k,String(v));
 }
 children.flat().forEach(x=>{if(x!==null&&x!==undefined)n.append(
  x instanceof Node?x:document.createTextNode(String(x)))});
 return n;
};
const routes={
 catalog:'products',media:'media',warehouse:'locations',delivery:'shipping_rates',
 tax:'tax_rules',storefront:'storefront',contact:'storefront',legal:'storefront',
 stock:'inventory_levels',buyers:'customers'
};
const labels={pass:'Contrôle vérifié',block:'Configuration manquante',manual:'Validation humaine requise'};
const colors={pass:'success',block:'danger',manual:'warning'};
export async function releaseCenter(storeId){
 const root=E('div',{className:'release-center'});
 const data=await api.rpc('chr_release_readiness',{p_store_id:storeId});
 const checks=Array.isArray(data?.checks)?data.checks:[];
 root.append(
  E('div',{className:'page-header'},
   E('div',{},
    E('div',{className:'eyebrow'},'AXIUM OS / PRÉPARATION PRODUCTION'),
    E('h1',{},'Centre de lancement CHR'),
    E('p',{className:'lead'},'Uniquement des contrôles vérifiés. Aucun bouton ici ne publie le site ou ne certifie sa sécurité.')
   )
  ),
  E('section',{className:'panel'},
   E('h2',{},data.checks_blocked>0?'Production non autorisée par les contrôles automatiques':'Contrôles automatiques complétés — validation finale encore nécessaire'),
   E('p',{},String(data.checks_passed)+' critères vérifiés · '+String(data.checks_blocked)+' configurations bloquantes · '+String(data.checks_manual)+' validations humaines.'),
   E('p',{className:'muted'},'Boutique actuellement '+(data.published?'publiée':'non publiée')+'. Cette page ne publie rien automatiquement.')
  ));
 const sections=E('section',{className:'panel'},E('h2',{},'Éléments à vérifier'));
 const list=E('div',{className:'release-items'});
 for(const item of checks){
  const actions=[];
  const dest=routes[item.key];
  if(dest)actions.push(E('button',{type:'button',className:'btn',
   onClick:()=>{location.hash='#/'+dest;}},'Ouvrir le module'));
  list.append(E('article',{className:'release-item release-'+item.status},
   E('div',{className:'release-item-content'},
    E('strong',{},item.label),
    E('span',{className:'release-pill '+colors[item.status]},labels[item.status]||item.status),
    E('p',{className:'muted'},item.details||'')),
   E('div',{className:'page-actions'},...actions)));
 }
 sections.append(list);root.append(sections);
 root.append(E('section',{className:'panel'},
   E('h2',{},'Preuves externes et responsabilité'),
   E('p',{},'Les tests PostgreSQL 17 et CodeQL ne démontrent pas les sauvegardes réelles, les paiements PSP, les parcours HTTP complets ni la conformité juridique.'),
   E('p',{},'Avant de publier : simulation de panne, restauration réussie, contrôle des accès avec deux vrais comptes, recette téléphone/ordinateur et accord du responsable CHR.'),
   E('div',{className:'page-actions'},
    E('a',{className:'btn',href:'https://github.com/aelhamri-art/CHR/pull/7',target:'_blank',rel:'noopener noreferrer'},'Consulter la PR de finition'),
    E('a',{className:'btn',href:'https://github.com/aelhamri-art/CHR/actions',target:'_blank',rel:'noopener noreferrer'},'Examiner les résultats des tests'))));
 return root;
}
