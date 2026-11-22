/**
 * AXIUM OS CHR — flexible, versioned B2B quotes and owner-set commercial policy.
 * All amounts, stock shortages, price caps, and tenant permissions are enforced
 * by PostgreSQL. This module is a UI, not a second business-rules engine.
 */
import * as api from './api.js';
import {parseMoney,parseInteger,formatMoney} from './rules.js';
const E=(tag,attributes={},...children)=>{
 const n=document.createElement(tag);
 for(const [k,v] of Object.entries(attributes)){
  if(v===null||v===undefined)continue;
  if(k==='className')n.className=v;
  else if(k==='onClick')n.addEventListener('click',v);
  else if(k==='onInput')n.addEventListener('input',v);
  else if(k==='onChange')n.addEventListener('change',v);
  else if(k==='onSubmit')n.addEventListener('submit',v);
  else if(k==='value')n.value=v;
  else if(k==='checked')n.checked=!!v;
  else if(k==='selected')n.selected=!!v;
  else if(k==='disabled')n.disabled=!!v;
  else if(k==='required')n.required=!!v;
  else if(k==='style')n.style.cssText=v;
  else n.setAttribute(k,String(v));
 }
 for(const v of children.flat(Infinity))if(v!==null&&v!==undefined)n.append(v instanceof Node?v:document.createTextNode(String(v)));
 return n;
};
const label=(name,element)=>E('label',{className:'field'},E('span',{},name),element);
const button=(name,fn,cls='btn')=>E('button',{type:'button',className:cls,onClick:fn},name);
const statusText={draft:'Brouillon',proposed:'Proposé (envoi externe)',accepted:'Accepté',declined:'Refusé',cancelled:'Annulé'};
const moneyInput=(minor)=>String((Number(minor)||0)/100);

function makeQuoteLine(storeId,existing=null){
 const box=E('div',{className:'workflow-card',style:'margin-bottom:10px;padding:14px'});
 const query=E('input',{type:'search',value:existing?.sku||'',placeholder:'Rechercher par SKU, nom ou référence…',autocomplete:'off'});
 const pick=E('select',{style:'width:100%;margin-top:8px'});
 const quantity=E('input',{type:'number',min:1,max:100000,step:1,value:existing?.quantity||1,required:true});
 const price=E('input',{type:'text',inputMode:'decimal',value:moneyInput(existing?.unit_price_minor||0),required:true});
 const reason=E('input',{type:'text',maxLength:500,value:existing?.price_reason||'',placeholder:'Obligatoire uniquement si prix négocié'});
 const status=E('small',{className:'muted'},existing?
  'Tarif catalogue à la révision : '+formatMoney(existing.list_unit_minor)+' • Pénurie indiquée : '+(existing.backorder_at_revision||0):
  'Sélectionne un article, puis adapte quantité et prix si nécessaire.');
 let selected=existing?{id:existing.variant_id,sku:existing.sku,price_minor:existing.list_unit_minor}:null;
 let serial=0,timer=null;
 function setResult(row,keepPrice=false){
  selected={id:row.id,sku:row.sku||row.title,price_minor:Number(row.price_minor)};
  query.value=row.sku||row.title||'';
  if(!keepPrice)price.value=moneyInput(row.price_minor);
  pick.replaceChildren();
  status.textContent='Catalogue HT : '+formatMoney(row.price_minor)+' • une modification de prix nécessite une justification.';
 }
 if(selected)pick.append(E('option',{value:selected.id},selected.sku));
 async function search(){
  const term=query.value.trim();
  if(term.length<2){pick.replaceChildren();status.textContent='Saisis au moins 2 caractères.';return;}
  const own=++serial;
  status.textContent='Recherche dans tout le catalogue…';
  try{
   const res=await api.adminCatalogPage(storeId,'product_variants',{query:term});
   if(own!==serial)return;
   const rows=res.rows||[];
   pick.replaceChildren(E('option',{value:''},rows.length?'Choisir la référence trouvée':'Aucune référence'));
   for(const row of rows)pick.append(E('option',{value:row.id},(row.sku||row.title)+' · '+formatMoney(row.price_minor)));
   pick._matches=rows;
   status.textContent=res.has_more?'50 premiers résultats. Précise la référence.':rows.length+' résultat(s) disponibles.';
  }catch(e){if(own===serial)status.textContent=e.message||'Recherche indisponible.';}
 }
 query.addEventListener('input',()=>{
  selected=null;
  clearTimeout(timer);
  timer=setTimeout(search,260);
 });
 pick.addEventListener('change',()=>{
  const row=(pick._matches||[]).find(r=>r.id===pick.value);
  if(row)setResult(row);
 });
 const remove=button('Supprimer cette ligne',()=>box.remove(),'text-btn danger');
 box.append(
  E('div',{className:'workflow-field'},label('Référence article',query),pick,status),
  E('div',{className:'form-grid'},label('Quantité',quantity),label('Prix proposé HT (€)',price)),
  label('Justification du prix négocié',reason),remove
 );
 box.quoteLine=()=>{
  if(!selected?.id)throw Error('Choisis une référence catalogue pour chaque ligne.');
  const qty=parseInteger(quantity.value,{min:1,max:100000});
  const agreed=parseMoney(price.value);
  const line={variant_id:selected.id,quantity:qty};
  if(agreed!==Number(selected.price_minor)){
   line.unit_price_minor=agreed;
   line.price_reason=reason.value.trim();
   if(line.price_reason.length<8)throw Error('Justifie le tarif négocié sur au moins 8 caractères.');
  }
  return line;
 };
 box.focusLookup=()=>query.focus();
 return box;
}

export async function salesQuotesPage(storeId,notify,onUpdated){
 const [quotes,customers]=await Promise.all([
  api.list('chr_sales_quotes',storeId,{limit:100,order:'updated_at.desc'}),
  api.list('customers',storeId,{limit:500,order:'created_at.desc'})
 ]);
 const root=E('div');
 const hero=E('div',{className:'page-header'},E('div',{},
  E('div',{className:'eyebrow'},'AXIUM OS / COMMERCE B2B'),
  E('h1',{},'Devis commerciaux'),
  E('p',{className:'lead'},'Créer, négocier, réviser et suivre des propositions sans jamais perdre la version acceptée.')),
  button('Nouveau devis',()=>openEditor(null),'btn accent'));
 const list=E('section',{className:'panel'},E('h2',{},'Dossiers récents'));
 const editor=E('section',{className:'panel',style:'display:none'});
 root.append(hero,list,editor);

 if(!quotes.length)list.append(E('p',{className:'muted'},'Aucun devis. Crée une proposition pour un client existant ou ponctuel.'));
 else {
  const tbody=E('tbody');
  for(const quote of quotes){
   const summary=(quote.lines||[]).reduce((n,l)=>n+Number(l.backorder_at_revision||0),0);
   const statusActions=E('div',{className:'action-inline'},
    button('Ouvrir',()=>openEditor(quote),'text-btn'),
    ...(quote.status==='draft'?[button('Marquer proposé',()=>transition(quote,'proposed'),'text-btn')]:[]),
    ...(quote.status==='proposed'?[button('Accepter',()=>transition(quote,'accepted'),'text-btn'),button('Refuser',()=>transition(quote,'declined'),'text-btn')]:[]),
    ...(quote.status==='accepted'?[button('Réviser',()=>openEditor(quote,true),'text-btn')]:[]),
    ...(['declined','cancelled'].includes(quote.status)?[button('Réouvrir',()=>transition(quote,'draft'),'text-btn')]:[])
   );
   tbody.append(E('tr',{},
    E('td',{},new Date(quote.updated_at).toLocaleDateString('fr-FR')),
    E('td',{},quote.company_name||quote.contact_email||'Sans entreprise'),
    E('td',{},'V'+quote.revision),
    E('td',{},statusText[quote.status]||quote.status),
    E('td',{},formatMoney(quote.subtotal_minor)),
    E('td',{},summary?summary+' unité(s) à commander':'—'),
    E('td',{},statusActions)));
  }
   const header=E('thead',{},E('tr',{},
    ...['Modifié','Client','Version','Statut','Estimation HT','À approvisionner','Actions']
      .map(name=>E('th',{},name))));
   const table=E('table',{className:'data-table'},header,tbody);
   list.append(E('div',{className:'table-wrap'},table),
    E('p',{className:'muted'},'100 derniers devis. Le suivi et les modifications sont conservés par révision.'));
 }

 async function transition(q,next){
  try{
   await api.rpc('chr_set_sales_quote_status',{
    p_store_id:storeId,p_quote_id:q.id,p_expected_revision:q.revision,
    p_new_status:next,p_reason:'Modification explicite du statut par un collaborateur'
   });
   notify('État du devis mis à jour.','success');await onUpdated();
  }catch(e){notify(e.message,'error');}
 }

 function openEditor(current=null,reopen=false){
  editor.style.display='';
  editor.replaceChildren(E('h2',{},current?'Réviser le devis — version '+current.revision:'Nouvelle proposition'));
  const form=E('form',{className:'form-grid'});
  const company=E('input',{type:'text',maxLength:180,value:current?.company_name||'',placeholder:'Entreprise ou prospect'});
  const email=E('input',{type:'email',maxLength:254,value:current?.contact_email||'',placeholder:'contact@entreprise.fr'});
  const customer=E('select',{},E('option',{value:''},'Sans fiche client (prospect ponctuel)'),
    ...customers.map(c=>E('option',{value:c.id,selected:current?.customer_id===c.id},c.company||c.email||c.first_name||c.id)));
  const notes=E('textarea',{rows:3,maxLength:5000},current?.notes||'');
  const rows=E('div');
  const existing=Array.isArray(current?.lines)?current.lines:[];
  function addLine(row=null){rows.append(makeQuoteLine(storeId,row));}
  if(existing.length)existing.forEach(addLine);else addLine();
  const inform=E('p',{className:'notice-inline'},
   'Ce devis ne réserve pas de stock : les unités indisponibles apparaissent comme à approvisionner. Prix et disponibilité sont revérifiés par le serveur.');
  const submit=E('button',{type:'submit',className:'btn accent'},current?'Enregistrer une nouvelle version':'Créer le devis');
  const cancel=button('Fermer',()=>{editor.style.display='none';},'btn');
  const actions=E('div',{className:'page-actions'},submit,cancel);
  form.append(
   label('Fiche client (optionnelle)',customer),
   label('Entreprise',company),label('Email de contact',email),
   label('Notes commerciales',notes),
   E('div',{},E('h3',{},'Articles et conditions'),
    button('Ajouter une ligne',()=>addLine(),'btn'),rows),
   inform,actions);
  const requestKey=crypto.randomUUID();
  form.addEventListener('submit',async ev=>{
   ev.preventDefault();submit.disabled=true;
   try{
    const lines=[...rows.children].map(x=>x.quoteLine());
    if(!lines.length)throw Error('Ajoute au moins une ligne.');
    const payload={
     p_store_id:storeId,p_lines:lines,
     p_quote_id:current?.id||null,p_expected_revision:current?.revision||null,
     p_customer_id:customer.value||null,
     p_company_name:company.value.trim()||null,
     p_contact_email:email.value.trim()||null,
     p_notes:notes.value.trim()||null,
     p_reopen:!!reopen,p_request_key:current?null:requestKey
    };
    const res=await api.rpc('chr_save_sales_quote',payload);
    notify('Devis enregistré, version '+res.revision+'. Historique conservé.','success');
    await onUpdated();
   }catch(e){notify(e.message||'Échec de validation du devis','error');}
   finally{submit.disabled=false;}
  });
  editor.append(form);
  editor.scrollIntoView({behavior:'smooth',block:'start'});
 }
 return root;
}

export async function businessPoliciesPage(storeId,isOwner,notify,onUpdated){
 const existing=(await api.list('chr_business_policies',storeId,{limit:1}))[0]||{};
 const root=E('div',{},E('div',{className:'page-header'},E('div',{},
  E('div',{className:'eyebrow'},'AXIUM OS / MAÎTRISE MÉTIER'),
  E('h1',{},'Politiques commerciales'),
  E('p',{className:'lead'},'La direction choisit les règles métier. Les opérations sensibles restent contrôlées par PostgreSQL.'))));
 const form=E('form',{className:'panel form-grid'});
 const negotiate=E('input',{type:'checkbox',checked:existing.allow_negotiated_prices??true,disabled:!isOwner});
 const max=E('input',{type:'number',min:0,max:100,step:1,value:(existing.max_price_reduction_bps??4000)/100,disabled:!isOwner});
 const quoteLines=E('input',{type:'number',min:1,max:500,step:1,value:existing.quote_line_limit??250,disabled:!isOwner});
 const backorder=E('input',{type:'checkbox',checked:existing.allow_backorder_quotes??true,disabled:!isOwner});
 form.append(
  E('h2',{},'Liberté commerciale encadrée'),
  label('Autoriser les prix négociés avec justification',negotiate),
  label('Réduction maximale autorisée par collaborateur (%)',max),
  label('Nombre maximal de lignes par devis interne',quoteLines),
  label('Autoriser les devis avec articles à approvisionner',backorder),
  E('p',{className:'muted'},'Seul le propriétaire peut changer ces paramètres. Les prix finaux et leurs motifs sont contrôlés et historisés côté serveur.'),
  E('button',{type:'submit',className:'btn accent',disabled:!isOwner},'Enregistrer la politique'));
 form.addEventListener('submit',async ev=>{
  ev.preventDefault();if(!isOwner)return;
  const b=form.querySelector('[type=submit]');b.disabled=true;
  try{
   const payload={
    allow_negotiated_prices:negotiate.checked,
    max_price_reduction_bps:parseInteger(max.value,{min:0,max:100})*100,
    quote_line_limit:parseInteger(quoteLines.value,{min:1,max:500}),
    allow_backorder_quotes:backorder.checked
   };
   await api.saveBusinessPolicy(storeId,payload);
   notify('Règles commerciales enregistrées et contrôlées côté serveur.','success');
   await onUpdated();
  }catch(e){notify(e.message,'error');}
  finally{b.disabled=false;}
 });
 root.append(form);
 return root;
}
