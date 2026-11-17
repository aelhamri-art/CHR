import * as api from './api.js';
import {MODULES,GROUPS} from './schema.js';
import {parseMoney,parseInteger,formatMoney,listText,textList,jsonInput,slugify,exportCsv} from './rules.js';

const root=document.getElementById('app');
const state={user:null,stores:[],store:null,route:'dashboard',busy:false};
const labels={draft:'Brouillon',active:'Actif',archived:'Archivé',pending:'En attente',open:'Ouvert',
 completed:'Terminé',paid:'Payé',failed:'Échec',unfulfilled:'Non préparé',fulfilled:'Expédié',
 manual:'Manuelle',automated:'Automatique',general:'Général',true:'Oui',false:'Non'};
const text=(s)=>document.createTextNode(String(s??''));
function E(tag,attrs={},...children) {
 const n=document.createElement(tag);
 for(const [k,v] of Object.entries(attrs)){
  if(v===undefined||v===null||v===false) continue;
  if(k==='className')n.className=v;
  else if(k==='text')n.textContent=String(v);
  else if(k==='htmlFor')n.htmlFor=v;
  else if(k.startsWith('on')&&typeof v==='function')n.addEventListener(k.slice(2).toLowerCase(),v);
  else if(k==='value')n.value=v;
  else if(k==='checked')n.checked=!!v;
  else if(k==='disabled')n.disabled=!!v;
  else if(k==='required')n.required=!!v;
  else n.setAttribute(k,String(v));
 }
 for(const c of children.flat(Infinity)){if(c===null||c===undefined||c===false)continue;n.append(c instanceof Node?c:text(c));}
 return n;
}
function btn(label,handler,cls='btn',extra={}){return E('button',{type:'button',className:cls,onclick:handler,...extra},label);}
function icon(name){const dict={dashboard:'◫',products:'▤',orders:'▣',settings:'⚙',customers:'♧',shipping:'⬡'};return dict[name]||'◈';}
function setMain(content) {const el=document.getElementById('main-content');if(el)el.replaceChildren(content);}
function notice(message,kind='info'){
 const target=document.getElementById('notices')||root;
 const el=E('div',{className:'toast '+kind,role:'status'},message);
 target.append(el);setTimeout(()=>el.remove(),5500);
}
function formatCell(v,k,table){
 if(v===null||v===undefined||v==='')return '—';
 if(k.endsWith('_minor'))return formatMoney(v,state.store?.currency||'EUR');
 if(typeof v==='boolean')return v?'Oui':'Non';
 if(Array.isArray(v))return v.join(', ');
 if(typeof v==='object')return JSON.stringify(v).slice(0,100);
 if(k.includes('_at')){const d=new Date(v);return isNaN(d.valueOf())?String(v):d.toLocaleString('fr-FR');}
 if(k.endsWith('_id'))return String(v).slice(0,8)+'…';
 return labels[String(v)]||String(v);
}
function pageHeader(title,description,buttons=[]){
 return E('div',{className:'page-header'},E('div',{},E('div',{className:'eyebrow'},'AXIUM COMMERCE OS / '+(state.store?.name||'CHR')),E('h1',{},title),E('p',{className:'lead'},description)),E('div',{className:'page-actions'},...buttons));
}
function panel(...content){return E('section',{className:'panel'},...content);}
function empty(title,message){return E('div',{className:'empty-state'},E('div',{className:'empty-icon'},'◻'),E('h3',{},title),E('p',{},message));}
function errorView(e){return panel(E('h3',{},'Une erreur est survenue'),E('p',{className:'error'},e?.message||'Erreur inconnue.'),btn('Réessayer',()=>navigate(state.route),'btn accent'));}
function loading(){return E('div',{className:'loading'},E('span',{className:'spinner'}),'Chargement des données…');}
async function safe(action,success){
 if(state.busy)return;
 state.busy=true;
 try {const value=await action();if(success)notice(success,'success');return value;}
 catch(e){notice(e?.message||'Action impossible','error');throw e;}
 finally{state.busy=false;}
}
function authScreen(message=''){
 root.replaceChildren(E('main',{className:'auth-page'},E('section',{className:'auth-box'},
 E('div',{className:'brand large'},E('span',{className:'brand-mark'},'A'),E('span',{},'AXIUM',E('small',{},'COMMERCE OS'))),
 E('div',{className:'auth-heading'},E('span',{className:'eyebrow'},'ACCÈS PROFESSIONNEL'),E('h1',{},'Votre commerce, sous contrôle.'),E('p',{},'Une administration indépendante, connectée directement à Supabase CHR.')),
 E('form',{id:'login-form',onsubmit:async e=>{
  e.preventDefault();
  const form=e.currentTarget,submit=form.querySelector('[type=submit]');submit.disabled=true;
  const fd=new FormData(form);
  try{await api.login(String(fd.get('email')).trim(),String(fd.get('password')));state.user=await api.currentUser();await enter();}
  catch(err){notice(err.message,'error');submit.disabled=false;}
 }},
 E('label',{},'Adresse e-mail',E('input',{name:'email',type:'email',autocomplete:'username',required:true,placeholder:'bonjour@entreprise.fr'})),
 E('label',{},'Mot de passe',E('input',{name:'password',type:'password',autocomplete:'current-password',required:true,minlength:6,placeholder:'••••••••'})),
 E('button',{type:'submit',className:'btn accent full'},'Se connecter')),
 E('div',{className:'auth-actions'},
 btn('Créer un compte',()=>authSecondary('signup'),'text-btn'),
 btn('Mot de passe oublié ?',()=>authSecondary('recover'),'text-btn')),
 message?E('p',{className:'error'},message):null,
 E('p',{className:'auth-footer'},'Accès protégé par authentification Supabase et politiques RLS.')
 )));
}
function authSecondary(type){
 const heading=type==='signup'?'Créer un accès':'Réinitialiser mon mot de passe';
 root.replaceChildren(E('main',{className:'auth-page'},E('section',{className:'auth-box'},
 E('div',{className:'brand large'},E('span',{className:'brand-mark'},'A'),'AXIUM COMMERCE OS'),
 E('h1',{},heading),E('p',{className:'lead'},type==='signup'?"Un e-mail de confirmation peut être nécessaire.":"Un lien sera envoyé si l'adresse existe."),
 E('form',{onsubmit:async e=>{
  e.preventDefault();const fd=new FormData(e.currentTarget);
  try{
   if(type==='signup')await api.register(String(fd.get('email')),String(fd.get('password')));
   else await api.resetPassword(String(fd.get('email')));
   notice('Demande enregistrée. Consulte tes e-mails.','success');authScreen();
  }catch(err){notice(err.message,'error');}
 }},
 E('label',{},'Adresse e-mail',E('input',{name:'email',type:'email',required:true})),
 type==='signup'?E('label',{},'Mot de passe (8 caractères minimum)',E('input',{name:'password',type:'password',required:true,minlength:8})):null,
 E('button',{type:'submit',className:'btn accent full'},type==='signup'?'Créer mon compte':'Envoyer le lien')),
 btn('Retour',()=>authScreen(),'text-btn')
 )));
}
async function enter(){
 try {
  state.stores=await api.getStores(state.user.id);
  const stored=sessionStorage.getItem('chr-selected-store');
  state.store=state.stores.find(s=>s.id===stored)||state.stores[0]||null;
  if(!state.store){onboard();return;}
  state.route=(location.hash.replace(/^#\/?/,'')||'dashboard');
  await renderShell();
 }catch(e){root.replaceChildren(errorView(e));}
}
function onboard(){
 root.replaceChildren(E('main',{className:'auth-page'},E('section',{className:'auth-box'},
 E('div',{className:'brand large'},E('span',{className:'brand-mark'},'A'),'AXIUM COMMERCE OS'),
 E('span',{className:'eyebrow'},'PREMIÈRE CONFIGURATION'),
 E('h1',{},'Créer votre entreprise'),
 E('p',{className:'lead'},'Les données seront isolées dans Supabase CHR. Aucun catalogue de démonstration ne sera injecté.'),
 E('form',{onsubmit:async e=>{
  e.preventDefault();const f=new FormData(e.currentTarget);const name=String(f.get('name')).trim();const slug=slugify(f.get('slug')||name);
  if(name.length<2||slug.length<2)return notice('Nom ou identifiant invalide.','error');
  try{state.store=await api.createStore(state.user.id,name,slug);state.stores=[...state.stores,state.store];sessionStorage.setItem('chr-selected-store',state.store.id);navigate('dashboard');}
  catch(err){notice(err.message,'error');}
 }},
 E('label',{},'Nom de l’entreprise',E('input',{name:'name',required:true,minlength:2,placeholder:'CHR Pro'})),
 E('label',{},'Identifiant unique (facultatif)',E('input',{name:'slug',placeholder:'chr-pro'})),
 E('button',{type:'submit',className:'btn accent full'},'Créer mon espace')),
 btn('Se déconnecter',async()=>{await api.logout();state.user=null;authScreen();},'text-btn')
 )));
}
function navigate(route) {location.hash='#/'+route;if(state.store){state.route=route;renderShell();}}
async function renderShell(){
 const shell=E('div',{className:'shell'},
 E('aside',{className:'sidebar',id:'sidebar'},
 E('div',{className:'brand'},E('span',{className:'brand-mark'},'A'),E('span',{},'AXIUM',E('small',{},'COMMERCE OS'))),
 E('div',{className:'sidebar-subtitle'},'ADMINISTRATION CHR'),
 E('nav',{className:'nav',ariaLabel:'Navigation principale'},...GROUPS.map(group=>E('div',{className:'nav-group'},
 E('h2',{},group.label),...group.items.map(([key,label,ico])=>E('a',{href:'#/'+key,className:'nav-link '+(state.route===key?'active':''),onclick:()=>{document.getElementById('sidebar')?.classList.remove('open');}},E('span',{className:'nav-icon'},icon(ico)),label))))),
 E('div',{className:'sidebar-bottom'},E('p',{},'Infrastructure indépendante'),E('span',{className:'micro'},'GitHub · Supabase CHR'))),
 E('div',{className:'workspace'},
 E('header',{className:'topbar'},btn('☰',()=>document.getElementById('sidebar')?.classList.toggle('open'),'menu-btn',{ariaLabel:'Afficher la navigation'}),
 E('div',{className:'store-switch'},E('label',{htmlFor:'select-store',className:'sr-only'},'Entreprise'),
 E('select',{id:'select-store',onchange:e=>{state.store=state.stores.find(s=>s.id===e.target.value);sessionStorage.setItem('chr-selected-store',state.store.id);navigate('dashboard');}},...state.stores.map(s=>E('option',{value:s.id,selected:s.id===state.store?.id},s.name)))),
 E('div',{className:'top-right'},E('span',{className:'chip'},'Supabase CHR'),E('span',{className:'avatar',title:state.user?.email||''},(state.user?.email||'A')[0].toUpperCase()),btn('Sortir',async()=>{await api.logout();state.user=null;state.store=null;authScreen();},'text-btn'))),
 E('div',{id:'notices',className:'notices'}),
 E('main',{id:'main-content',className:'main'},loading())));
 root.replaceChildren(shell);
 await renderPage();
}
async function renderPage(){
 const route=state.route;
 setMain(loading());
 try{
  if(route==='dashboard')return await renderDashboard();
  if(route==='settings')return await renderSettings();
  if(MODULES[route])return await renderModule(route);
  state.route='dashboard';return renderDashboard();
 }catch(e){setMain(errorView(e));}
}
async function renderDashboard(){
 const [products,variants,customers,orders,locations,alerts]=await Promise.all([
 api.list('products',state.store.id),api.list('product_variants',state.store.id),
 api.list('customers',state.store.id),api.list('orders',state.store.id),
 api.list('locations',state.store.id),api.list('inventory_levels',state.store.id)
 ]);
 if(state.route!=='dashboard')return;
 const total=orders.filter(o=>o.payment_status==='paid'||o.payment_status==='partially_refunded').reduce((a,o)=>a+Number(o.total_minor||0),0);
 const low=alerts.filter(a=>Number(a.on_hand||0)-Number(a.reserved||0)<3);
 const cards=[
 ['Produits',products.length,'Fiches catalogue'],['Références SKU',variants.length,'Variantes actives ou archivées'],
 ['Clients B2B',customers.length,'Comptes enregistrés'],['Commandes',orders.length,'Opérations stockées'],
 ['CA encaissé',formatMoney(total),'D’après les commandes au statut payé'],['Stock faible',low.length,'Moins de 3 unités disponibles']
 ];
 setMain(E('div',{},pageHeader('Vue d’ensemble','Données réelles, calculées sur la base CHR.'),E('section',{className:'metric-grid'},...cards.map(c=>E('div',{className:'metric'},E('p',{},c[0]),E('strong',{},c[1]),E('small',{},c[2])))),
 E('div',{className:'two-col'},panel(E('h2',{},'Actions utiles'),E('div',{className:'quick-actions'},
 btn('Créer un produit',()=>navigate('products'),'btn accent'),btn('Ajouter une variante',()=>navigate('product_variants')),
 btn('Configurer la livraison',()=>navigate('shipping_rates')),btn('Voir les stocks',()=>navigate('inventory_levels'))),
 E('p',{className:'muted'},'Aximus : emplacement réservé. Aucun agent n’exécute d’actions à ce stade.')),
 panel(E('h2',{},'État opérationnel'),E('dl',{className:'stats-list'},
 ...[['Entreprises',state.stores.length],['Entrepôts',locations.length],['Commandes ouvertes',orders.filter(o=>o.status==='open').length],['Références en stock faible',low.length]].map(([k,v])=>E('div',{},E('dt',{},k),E('dd',{},v)))),
 E('p',{className:'muted'},'Les paiements nécessitent un prestataire connecté et des webhooks testés.')))));
}
function tableData(table,search){
 const q=search.trim().toLowerCase();
 return table.filter(row=>!q||Object.values(row).some(value=>String(value??'').toLowerCase().includes(q)));
}
async function renderModule(key){
 const spec=MODULES[key],storeId=state.store.id;
 const rows=await api.list(key,storeId,{limit:1000});
 if(state.route!==key)return;
 const filter=E('input',{type:'search',placeholder:'Rechercher dans les résultats',ariaLabel:'Filtrer les résultats',className:'search-input'});
 const tbody=E('tbody');
 const table=E('table',{className:'data-table'},E('thead',{},E('tr',{},...spec.columns.map(k=>E('th',{},columnLabel(k))),E('th',{},'Actions'))),tbody);
 const counter=E('span',{className:'micro'},rows.length+' enregistrement(s)');
 const renderRows=()=>{
  const displayed=tableData(rows,filter.value);
  tbody.replaceChildren(...displayed.map(row=>E('tr',{},...spec.columns.map(col=>E('td',{},E('span',{className:col==='status'?'pill':''},formatCell(row[col],col,key)))),
 E('td',{className:'row-actions'},spec.readOnly?E('span',{className:'micro'},'Consultation'):E('div',{className:'action-inline'},
 btn('Modifier',()=>openForm(key,row),'text-btn'),
 btn(key==='products'?'Archiver':'Supprimer',()=>deleteRecord(key,row),'text-btn danger'))))));
  counter.textContent=displayed.length+' / '+rows.length+' enregistrement(s)';
 };
 filter.addEventListener('input',renderRows);
 renderRows();
 const buttons=[
 btn('Exporter CSV',()=>{const csv=exportCsv(rows,spec.columns);const blob=new Blob(['\uFEFF',csv],{type:'text/csv;charset=utf-8;'});const a=E('a',{href:URL.createObjectURL(blob),download:'chr-'+key+'-'+new Date().toISOString().slice(0,10)+'.csv'});a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);}),
 ...(spec.readOnly?[]:[btn('Créer',()=>openForm(key),'btn accent')])
 ];
 const content=E('div',{},pageHeader(spec.label,spec.description,buttons),
 panel(E('div',{className:'table-toolbar'},filter,counter),rows.length?E('div',{className:'table-wrap'},table):empty('Aucune donnée enregistrée','Les données s’afficheront ici dès leur création.')),
 spec.readOnly?E('p',{className:'notice-inline'},'Lecture seule : les opérations sensibles doivent passer par une commande serveur transactionnelle.'):null);
 if(key==='inventory_levels')content.append(await inventoryAdjust());
 if(key==='shipping_rates')content.append(await shippingTester());
 if(key==='orders')content.append(E('p',{className:'notice-inline'},'Le moteur de création de commandes doit être validé côté serveur avant activation des actions commerciales.'));
 if(key==='collections')content.append(E('p',{className:'notice-inline'},'Les collections automatiques enregistrent leurs règles, mais leur évaluation dynamique n’est pas encore active.'));
 setMain(content);
}
function columnLabel(s){return ({title:'Nom',product_id:'Produit',sku:'SKU',status:'État',price_minor:'Prix',total_minor:'Total',amount_minor:'Montant',on_hand:'Physique',reserved:'Réservé',created_at:'Créé',updated_at:'Modifié',order_number:'Commande',name:'Nom',mode:'Calcul',zone_id:'Zone',profile_id:'Profil',countries:'Pays',postal_prefixes:'Codes postaux',variant_id:'Variante',location_id:'Emplacement',company:'Entreprise',email:'E-mail',valid_until:'Expire',active:'Actif',is_general:'Général',taxable:'Taxable',payment_status:'Paiement',fulfillment_status:'Préparation',unit_price_minor:'Prix unitaire',quantity:'Quantité',action:'Action',entity_type:'Entité',actor_type:'Auteur',entity_id:'Élément',kind:'Type'})[s]||s.replaceAll('_',' ');}
function readableFieldValue(val,f){
 if(val===undefined||val===null)return '';
 if(f.type==='money')return (Number(val)/100).toFixed(2);
 if(f.type==='list'||f.type==='upper_list')return textList(val);
 if(f.type==='json'||f.type==='json_array')return JSON.stringify(val,null,2);
 if(f.type==='datetime')return String(val).slice(0,16);
 return val;
}
function normalizeField(val,f){
 if(f.type==='boolean')return !!val;
 if(val===''||val===null||val===undefined)return f.required?'':null;
 if(f.type==='money')return parseMoney(val);
 if(f.type==='integer')return parseInteger(val,{min:f.min??0});
 if(f.type==='list')return listText(val);
 if(f.type==='upper_list')return listText(val).map(x=>x.toUpperCase());
 if(f.type==='json')return jsonInput(val,'object');
 if(f.type==='json_array')return jsonInput(val,'array');
 if(f.type==='datetime')return new Date(val).toISOString();
 if(f.type==='slug')return slugify(val);
 return String(val).trim();
}
async function openForm(key,row=null){
 const spec=MODULES[key];
 if(spec.readOnly)return;
 let relations={};
 for(const f of spec.fields){if(f.type==='relation')relations[f.name]=await api.getRelated(f.table,state.store.id);}
 const form=E('form',{className:'form-grid',id:'record-editor-form'});
 const controls=new Map();
 for(const f of spec.fields){
  const id='field-'+f.name;
  let input;
  const v=readableFieldValue(row?.[f.name],f);
  if(f.type==='select'||f.type==='relation'){
   const options=f.type==='relation'?(relations[f.name]||[]).map(r=>({value:r.id,label:r[f.display]||r.id})):f.options;
   input=E('select',{id,name:f.name,required:!!f.required},
   !f.required?E('option',{value:''},'Non renseigné'):null,
   ...options.map(o=>E('option',{value:o.value,selected:o.value===v},o.label)));
  }else if(f.type==='boolean')input=E('input',{id,type:'checkbox',name:f.name,checked:row?!!row[f.name]:false});
  else if(f.type==='textarea'||f.type==='json'||f.type==='json_array') {
   input=E('textarea',{id,name:f.name,rows:f.type==='textarea'?4:5},v);
  }else input=E('input',{id,name:f.name,type:f.type==='email'?'email':f.type==='integer'?'number':f.type==='datetime'?'datetime-local':'text',
   value:v,required:!!f.required,step:f.type==='integer'?'1':undefined,maxlength:f.max});
  controls.set(f.name,input);
  form.append(E('label',{className:'field '+(f.type==='boolean'?'check-field':'')},E('span',{},f.label),input));
 }
 const saveButton=E('button',{className:'btn accent',type:'submit',form:'record-editor-form'},row?'Enregistrer les modifications':'Créer et enregistrer');
 const dialog=E('dialog',{className:'modal',ariaLabel:(row?'Modifier ':'Créer ')+spec.label},
 E('div',{className:'dialog-head'},E('div',{},E('span',{className:'eyebrow'},'DONNÉES PERSISTANTES'),E('h2',{},(row?'Modifier ':'Créer ')+spec.label)),btn('✕',()=>dialog.close(),'icon-btn',{ariaLabel:'Fermer'})),
 form,E('div',{className:'dialog-footer'},btn('Annuler',()=>dialog.close()),saveButton));
 document.body.append(dialog);dialog.addEventListener('close',()=>dialog.remove());
 form.addEventListener('submit',async event=>{
  event.preventDefault();saveButton.disabled=true;
  try{
   const payload={};
   for(const f of spec.fields){
    let value=normalizeField(f.type==='boolean'?controls.get(f.name).checked:controls.get(f.name).value,f);
    if(f.required&&(value===''||value===null))throw new Error(f.label+' est obligatoire.');
    payload[f.name]=value;
   }
   if(key==='products'&&!payload.handle)payload.handle=slugify(payload.title);
   if(row) {
    if(spec.key==='composite')throw new Error('Modification des associations indisponible : supprimer puis recréer.');
    await api.update(key,row.id,state.store.id,payload);
   }else{
    payload.store_id=state.store.id;
    await api.insert(key,payload);
   }
   dialog.close();notice('Données enregistrées dans Supabase.','success');await renderPage();
  }catch(e){notice(e.message,'error');}
  finally{saveButton.disabled=false;}
 });
 dialog.showModal();
}
async function deleteRecord(key,row){
 if(!confirm(key==='products'?'Archiver ce produit ?':'Supprimer définitivement cet enregistrement ?'))return;
 try {
  if(key==='products')await api.update(key,row.id,state.store.id,{status:'archived'});
  else if(key==='collection_products')await api.removeByFields(key,{store_id:state.store.id,collection_id:row.collection_id,product_id:row.product_id});
  else await api.remove(key,row.id,state.store.id);
  notice('Opération enregistrée.','success');await renderPage();
 }catch(e){notice(e.message,'error');}
}
async function inventoryAdjust(){
 const wrap=panel(E('h2',{},'Ajustement sécurisé du stock'),E('p',{className:'muted'},'Commande serveur atomique, traçable, avec clé anti-doublon.'));
 const [variants,locations]=await Promise.all([api.list('product_variants',state.store.id),api.list('locations',state.store.id)]);
 if(!variants.length||!locations.length){wrap.append(empty('Configuration nécessaire','Ajoute d’abord une variante et un entrepôt.'));return wrap;}
 const form=E('form',{className:'inline-form'});
 const variant=E('select',{name:'variant',required:true},...variants.map(v=>E('option',{value:v.id},v.sku||v.title)));
 const location=E('select',{name:'location',required:true},...locations.map(l=>E('option',{value:l.id},l.name)));
 const delta=E('input',{name:'delta',type:'number',step:1,placeholder:'± quantité',required:true});
 const reason=E('select',{name:'reason'},...[['receipt','Réception'],['correction','Correction'],['damage','Casse'],['return','Retour'],['manual','Manuel']].map(([v,l])=>E('option',{value:v},l)));
 const submit=E('button',{type:'submit',className:'btn accent'},'Appliquer');
 form.append(E('label',{},'Variante',variant),E('label',{},'Entrepôt',location),E('label',{},'Variation',delta),E('label',{},'Motif',reason),submit);
 form.addEventListener('submit',async e=>{
  e.preventDefault();submit.disabled=true;
  try {
   const amount=parseInteger(delta.value,{min:-100000000,max:100000000});
   if(amount===0)throw new Error('Variation nulle interdite.');
   const result=await api.rpc('adjust_inventory',{p_store_id:state.store.id,p_variant_id:variant.value,p_location_id:location.value,p_delta:amount,p_reason:reason.value,p_idempotency_key:crypto.randomUUID()});
   notice('Stock enregistré : '+result.on_hand+' unités physiques.','success');await renderPage();
  }catch(err){notice(err.message,'error');}
  finally{submit.disabled=false;}
 });
 wrap.append(form);return wrap;
}
async function shippingTester(){
 const wrap=panel(E('h2',{},'Tester les tarifs configurés'),E('p',{className:'muted'},'Le calcul interroge les règles enregistrées en base. Les tarifs transporteurs connectés nécessitent une API externe.'));
 const profiles=await api.list('shipping_profiles',state.store.id);
 if(!profiles.length){wrap.append(empty('Aucun profil','Crée d’abord un profil de livraison.'));return wrap;}
 const form=E('form',{className:'inline-form'});
 const profile=E('select',{required:true},...profiles.map(p=>E('option',{value:p.id},p.name)));
 const country=E('input',{value:'FR',maxLength:2,required:true,ariaLabel:'Code pays ISO'});
 const postal=E('input',{value:'33000',required:true,ariaLabel:'Code postal'});
 const weight=E('input',{value:'2500',type:'number',min:0,required:true,ariaLabel:'Poids en grammes'});
 const subtotal=E('input',{value:'100',required:true,ariaLabel:'Sous-total en euros'});
 const result=E('div',{className:'shipping-result'});
 form.append(E('label',{},'Profil',profile),E('label',{},'Pays',country),E('label',{},'Code postal',postal),E('label',{},'Poids en grammes',weight),E('label',{},'Sous-total HT (€)',subtotal),E('button',{type:'submit',className:'btn accent'},'Calculer'));
 form.addEventListener('submit',async e=>{
  e.preventDefault();result.replaceChildren(loading());
  try{
   const rates=await api.rpc('eligible_shipping_rates',{p_store_id:state.store.id,p_profile_id:profile.value,p_country:country.value.trim().toUpperCase(),p_postal_code:postal.value.trim(),p_weight_grams:parseInteger(weight.value),p_subtotal_minor:parseMoney(subtotal.value)});
   result.replaceChildren((rates?.length)?E('ul',{className:'rates-list'},...rates.map(r=>E('li',{},E('strong',{},r.rate_name),' — '+formatMoney(r.amount_minor)))):empty('Aucun tarif éligible','Vérifie pays, zone, poids et seuils.'));
  }catch(err){result.replaceChildren(E('p',{className:'error'},err.message));}
 });
 wrap.append(form,result);return wrap;
}
async function renderSettings(){
 const store=state.store;
 const form=E('form',{className:'form-grid'},
 E('label',{className:'field'},E('span',{},'Nom de l’entreprise'),E('input',{name:'name',value:store.name,required:true})),
 E('label',{className:'field'},E('span',{},'Devise ISO'),E('input',{name:'currency',value:store.currency,required:true,maxLength:3})),
 E('label',{className:'field'},E('span',{},'Fuseau horaire'),E('input',{name:'timezone',value:store.timezone,required:true})),
 E('button',{type:'submit',className:'btn accent'},'Enregistrer'));
 form.addEventListener('submit',async e=>{
  e.preventDefault();const f=new FormData(form);
  try{
   const updated=await api.updateStore(store.id,{name:String(f.get('name')),currency:String(f.get('currency')).toUpperCase(),timezone:String(f.get('timezone'))});
   state.store=updated;state.stores=state.stores.map(s=>s.id===updated.id?updated:s);
   notice('Configuration mise à jour.','success');renderShell();
  }catch(err){notice(err.message,'error');}
 });
 const members=await api.list('store_members',store.id);
 setMain(E('div',{},pageHeader('Paramètres','Votre entreprise, sa configuration et les accès autorisés.'),
 panel(E('h2',{},'Entreprise'),form),
 panel(E('h2',{},'Collaborateurs'),members.length?E('ul',{},...members.map(m=>E('li',{},m.user_id.slice(0,8)+'… · '+m.role+' · '+m.status))):empty('Aucun collaborateur','L’invitation d’un nouvel utilisateur exige un flux d’authentification sécurisé.'),
 E('p',{className:'muted'},'Les invitations, accès avancés, paiements, transporteurs et Aximus nécessitent une configuration spécifique avant activation.'))));
}
async function boot(){
 if(!api.configured()){root.replaceChildren(E('main',{className:'auth-page'},panel(E('h1',{},'Configuration requise'),E('p',{},'Renseigne config.js avec une clé publique de Supabase CHR.'))));return;}
 if(!api.getSession()){authScreen();return;}
 try{state.user=await api.currentUser();if(!state.user){authScreen();return;}await enter();}
 catch(e){authScreen(e.message);}
}
window.addEventListener('hashchange',()=>{if(state.store){state.route=location.hash.replace(/^#\/?/,'')||'dashboard';renderShell();}});
boot();
