/* Workflows commerciaux : aucun prix, stock ou état de paiement modifié côté navigateur. */
import * as api from './api.js';
import {parseInteger,parseMoney,formatMoney} from './rules.js';
function el(tag,props={},...children){
 const node=document.createElement(tag);
 for(const [key,value] of Object.entries(props)){
  if(key==='className')node.className=value;
  else if(key==='onClick')node.addEventListener('click',value);
  else if(key==='onSubmit')node.addEventListener('submit',value);
  else if(key==='value')node.value=value;
  else if(key==='type')node.type=value;
  else if(key==='name')node.name=value;
  else if(key==='required')node.required=!!value;
  else node.setAttribute(key,String(value));
 }
 children.flat().forEach(c=>{if(c!==null&&c!==undefined)node.append(c instanceof Node?c:document.createTextNode(String(c)));});
 return node;
}
function select(items,display='name'){return el('select',{},...items.map(row=>el('option',{value:row.id},String(row[display]||row.id))));}
function field(title,control){return el('label',{className:'workflow-field'},el('span',{},title),control);}
function actionForm(title,description,content,onSubmit){
 const form=el('form',{className:'workflow-form',onSubmit},...content);
 return el('section',{className:'workflow-card'},el('h3',{},title),el('p',{className:'muted'},description),form);
}
export async function ordersPanel(storeId,onUpdated,notify){
 const [customers,locations,profiles,orders,taxes,firstCatalog,policies]=await Promise.all([
  api.list('customers',storeId),api.list('locations',storeId),api.list('shipping_profiles',storeId),
  api.list('orders',storeId),api.list('tax_rules',storeId),
  api.adminCatalogPage(storeId,'product_variants'),api.list('chr_business_policies',storeId,{limit:1})
 ]);
 const priceNegotiationEnabled=policies[0]?.allow_negotiated_prices??true;
 const outer=el('div',{className:'workflow-zone'},el('h2',{},'Opérations commerciales réelles'));
 const isReady=customers.length>0&&locations.length>0&&profiles.length>0&&(firstCatalog.rows||[]).length>0&&taxes.length>0;
 if(!isReady)outer.append(el('p',{className:'notice-inline'},'Avant de créer une commande, renseigne un client, un entrepôt, une variante avec du stock, un profil de livraison et une règle fiscale. Aucun prix ou taxe ne sera inventé.'));
 if(isReady){
  const customer=select(customers,'company');
  const location=select(locations);
  const profile=select(profiles);
  const country=el('input',{value:'FR',maxLength:'2',required:true,placeholder:'FR'});
  const postal=el('input',{required:true,placeholder:'33000'});
  const lines=el('div',{className:'workflow-lines'});
  function addLine(){
   const row=el('div',{className:'workflow-line'});
   const search=el('input',{type:'search',placeholder:'Rechercher SKU / désignation',autocomplete:'off'});
   const chosen=el('select',{},el('option',{value:''},'Sélectionne une référence'));
   const quantity=el('input',{type:'number',min:'1',max:'100000',step:'1',value:'1',required:true});
   const unitPrice=el('input',{type:'text',placeholder:'Prix HT négocié (€)',disabled:!priceNegotiationEnabled});
   const priceReason=el('input',{type:'text',placeholder:'Motif du prix personnalisé',disabled:!priceNegotiationEnabled});
   const hint=el('small',{className:'muted'},'Recherche dans l’ensemble des références.');
   let matches=[],selected=null,requestId=0,timer;
   async function searchCatalog(){
     const query=search.value.trim();
     if(query.length<2){hint.textContent='Saisis au moins 2 caractères.';return;}
     const current=++requestId;
     try{
       const page=await api.adminCatalogPage(storeId,'product_variants',{query});
       if(current!==requestId)return;
       matches=page.rows||[];
       chosen.replaceChildren(el('option',{value:''},'Choisir une référence'),
         ...matches.map(v=>el('option',{value:v.id},(v.sku||v.title)+' — '+formatMoney(v.price_minor))));
       hint.textContent=page.has_more?'Précise la référence pour réduire les résultats.':matches.length+' résultat(s)';
     }catch(e){if(current===requestId)hint.textContent=e.message;}
   }
   search.addEventListener('input',()=>{
     selected=null;clearTimeout(timer);timer=setTimeout(searchCatalog,260);
   });
   chosen.addEventListener('change',()=>{
     selected=matches.find(v=>v.id===chosen.value)||null;
     if(selected){search.value=selected.sku||selected.title;unitPrice.value=String(selected.price_minor/100);hint.textContent='Prix catalogue : '+formatMoney(selected.price_minor);}
   });
   const remove=el('button',{type:'button',className:'btn',onClick:()=>row.remove()},'Retirer');
   row.append(field('Rechercher une référence',search),chosen,hint,
    field('Quantité',quantity),
    ...(priceNegotiationEnabled?[field('Prix HT à appliquer (€)',unitPrice),field('Justification si différent du tarif catalogue',priceReason)]:[]),
    remove);
   row.getOrderLine=()=>{
     if(!selected)throw Error('Sélectionne une référence pour chaque ligne.');
     const line={variant_id:selected.id,quantity:parseInteger(quantity.value,{min:1,max:100000})};
     if(priceNegotiationEnabled){
       const agreed=parseMoney(unitPrice.value);
       if(agreed!==Number(selected.price_minor)){
         line.unit_price_minor=agreed;
         line.price_reason=priceReason.value.trim();
         if(line.price_reason.length<8)throw Error('Motif de négociation obligatoire : 8 caractères minimum.');
       }
     }
     return line;
   };
   lines.append(row);
  }
  addLine();
  const create=actionForm('Nouvelle commande','Les montants, le port, la TVA et la réservation du stock sont calculés dans PostgreSQL.',[
   field('Client',customer),field('Entrepôt',location),field('Profil de livraison',profile),
   field('Pays ISO',country),field('Code postal',postal),field('Variantes × quantités',lines),
   el('button',{type:'button',className:'btn',onClick:addLine},'Ajouter une ligne'),
   el('button',{type:'submit',className:'btn accent'},'Créer la commande')
  ],async event=>{
   event.preventDefault();
   const submit=event.currentTarget.querySelector('[type=submit]');submit.disabled=true;
   try{
    const entries=[...lines.querySelectorAll('.workflow-line')].map(row=>row.getOrderLine());
    if(!entries.length)throw new Error('Ajoute au moins une ligne.');
    const result=await api.rpc('create_order',{
     p_store_id:storeId,p_customer_id:customer.value,p_location_id:location.value,
     p_shipping_profile_id:profile.value,p_country:country.value.trim().toUpperCase(),
     p_postal:postal.value.trim(),p_lines:entries,p_idempotency_key:crypto.randomUUID()
    });
    notify('Commande #'+result.order_number+' créée en base, total '+formatMoney(result.total_minor),'success');await onUpdated();
   }catch(error){notify(error.message,'error');}
   finally{submit.disabled=false;}
  });
  outer.append(create);
 }
 if(orders.length){
  const orderList=orders.filter(row=>row.status==='open');
  if(orderList.length){
   const pick=el('select',{},...orderList.map(o=>el('option',{value:o.id},'#'+o.order_number+' · '+formatMoney(o.total_minor)+' · '+o.payment_status)));
   const reference=el('input',{required:true,placeholder:'Référence virement ou reçu'});
   const method=el('select',{},el('option',{value:'bank_transfer'},'Virement bancaire'),el('option',{value:'cash'},'Espèces'),el('option',{value:'cheque'},'Chèque'));
   const confirm=el('input',{required:true,placeholder:'Saisir PAIEMENT RECU'});
   outer.append(actionForm('Confirmer un paiement manuel',"N'enregistre AUCUN mouvement bancaire. À utiliser uniquement après vérification humaine de l'encaissement.",[
    field('Commande',pick),field('Moyen réel',method),field('Référence de paiement',reference),field('Validation humaine',confirm),
    el('button',{type:'submit',className:'btn accent'},'Enregistrer le règlement reçu')
   ],async e=>{
    e.preventDefault();const b=e.currentTarget.querySelector('[type=submit]');b.disabled=true;
    try{await api.rpc('confirm_manual_payment',{p_store_id:storeId,p_order_id:pick.value,p_method:method.value,p_reference:reference.value.trim(),p_confirmation:confirm.value.trim()});notify('Paiement manuel enregistré et historisé.','success');await onUpdated();}
    catch(err){notify(err.message,'error');}
    finally{b.disabled=false;}
   }));
   const eligible=orderList.filter(o=>o.payment_status==='paid'&&o.fulfillment_status==='unfulfilled');
   if(eligible.length){
    const chosen=el('select',{},...eligible.map(o=>el('option',{value:o.id},'#'+o.order_number)));
    const carrier=el('input',{required:true,placeholder:'Transporteur / remise directe'});
    const tracking=el('input',{required:true,minLength:'4',placeholder:'Numéro de suivi ou référence de remise'});
    outer.append(actionForm('Confirmer une expédition','Cette action débite définitivement le stock réservé. Aucune étiquette transporteur n’est générée.',[
     field('Commande payée',chosen),field('Transporteur',carrier),field('Suivi',tracking),
     el('button',{type:'submit',className:'btn accent'},'Marquer expédiée')
    ],async e=>{
     e.preventDefault();const b=e.currentTarget.querySelector('[type=submit]');b.disabled=true;
     try{await api.rpc('fulfill_paid_order',{p_store_id:storeId,p_order_id:chosen.value,p_carrier:carrier.value.trim(),p_tracking:tracking.value.trim()});notify('Expédition confirmée et stock débité.','success');await onUpdated();}
     catch(err){notify(err.message,'error');}
     finally{b.disabled=false;}
    }));
   }
   const cancellable=orderList.filter(o=>o.payment_status==='pending'&&o.fulfillment_status==='unfulfilled');
   if(cancellable.length){
    const chosen=el('select',{},...cancellable.map(o=>el('option',{value:o.id},'#'+o.order_number)));
    outer.append(actionForm('Annuler une commande non payée','Libère les quantités réservées dans la même transaction SQL.',[
     field('Commande',chosen),el('button',{type:'submit',className:'btn danger-btn'},'Annuler et libérer le stock')
    ],async e=>{
     e.preventDefault();if(!confirm('Annuler cette commande et libérer les réservations ?'))return;
     const b=e.currentTarget.querySelector('[type=submit]');b.disabled=true;
     try{await api.rpc('cancel_pending_order',{p_store_id:storeId,p_order_id:chosen.value});notify('Commande annulée. Réservations libérées.','success');await onUpdated();}
     catch(err){notify(err.message,'error');}
     finally{b.disabled=false;}
    }));
   }
  }
 }
 outer.append(el('p',{className:'notice-inline'},'Hors intégration : cartes bancaires, remboursements bancaires, étiquettes transporteurs, commandes partielles et marketplaces. Ces fonctions exigent des prestataires ou modules supplémentaires.'));
 return outer;
}
