import * as api from './api.js';
import {catalogFromCsv} from './csv.js';
import {formatMoney} from './rules.js';
function E(tag,attrs={},...children){
 const n=document.createElement(tag);
 for(const [key,v] of Object.entries(attrs)){
  if(key==='className')n.className=v;
  else if(key==='onClick')n.addEventListener('click',v);
  else if(key==='type')n.type=v;
  else if(key==='value')n.value=v;
  else if(key==='accept')n.accept=v;
  else n.setAttribute(key,String(v));
 }
 children.flat().forEach(c=>{if(c!==undefined&&c!==null)n.append(c instanceof Node?c:document.createTextNode(String(c)));});
 return n;
}
export function importPage(storeId,onDone,notify) {
 let records=[],idempotency=crypto.randomUUID();
 const file=E('input',{type:'file',accept:'.csv,text/csv'});
 const output=E('div',{className:'csv-preview'});
 const apply=E('button',{className:'btn accent',type:'button'},'Importer dans Supabase');
 apply.disabled=true;
 function renderPreview(){
  output.replaceChildren(E('p',{className:'muted'},records.length+' variantes prêtes à être créées ou mises à jour. L’import est atomique : toute erreur annule le lot.'));
  if(!records.length)return;
  const t=E('table',{className:'data-table'},E('thead',{},E('tr',{},
   ...['Produit','Catégorie','SKU','Prix HT','Statut'].map(h=>E('th',{},h)))),
  E('tbody',{},...records.slice(0,15).map(row=>E('tr',{},E('td',{},row.title),
   E('td',{},row.category||'—'),E('td',{},row.sku),E('td',{},formatMoney(row.price_minor)),E('td',{},row.status)))));
  output.append(E('div',{className:'table-wrap'},t));
  if(records.length>15)output.append(E('p',{className:'muted'},'Affichage limité aux 15 premières lignes.'));
 }
 file.addEventListener('change',async()=>{
  records=[];apply.disabled=true;output.replaceChildren();
  try{
   const chosen=file.files?.[0];if(!chosen)return;
   if(chosen.size>2*1024*1024)throw new Error('Fichier supérieur à 2 Mo.');
   records=catalogFromCsv(await chosen.text());
   idempotency=crypto.randomUUID();
   apply.disabled=false;renderPreview();
  }catch(error){notify(error.message,'error');output.append(E('p',{className:'error'},error.message));}
 });
 apply.addEventListener('click',async()=>{
  if(!records.length)return;
  if(!confirm('Importer '+records.length+' lignes dans le catalogue réel ?'))return;
  apply.disabled=true;
  try{
   const result=await api.rpc('import_products_batch',{p_store_id:storeId,p_rows:records,p_idempotency_key:idempotency});
   notify(result.count+' variantes importées (statut '+result.status+').','success');
   records=[];file.value='';output.replaceChildren();await onDone();
  }catch(error){notify(error.message,'error');apply.disabled=false;}
 });
 const sample='Handle,Title,Vendor,Category,Variant SKU,Variant Price,Variant Grams,Published\r\nfour-pro,Four mixte professionnel,Fournisseur CHR,Cuisson,FOUR-01,6490.00,96000,TRUE\r\n';
 const example=E('button',{type:'button',className:'btn',onClick:()=>{
  const blob=new Blob(['\uFEFF',sample],{type:'text/csv;charset=utf-8;'});
  const link=E('a',{href:URL.createObjectURL(blob),download:'chr-produit-exemple.csv'});link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);
 }},'Télécharger un modèle');
 return E('div',{},
 E('div',{className:'page-header'},E('div',{},E('span',{className:'eyebrow'},'CATALOGUE / IMPORT'),E('h1',{},'Importer des produits'),
  E('p',{className:'lead'},'Import de produits CHR depuis un CSV UTF-8, avec une colonne SKU par variante.'))),
 E('section',{className:'panel'},E('h2',{},'Préparer un fichier CSV'),E('p',{className:'muted'},
  'Colonnes acceptées : Handle, Title, Vendor, Category, Variant SKU, Variant Price, Variant Grams, Published. Ou handle, title, vendor, sku, price_eur, weight_g, status.'),
  E('p',{className:'notice-inline'},'Format partiel compatible avec les colonnes Shopify. Les métachamps, collections et images ne sont pas importés. Aucune suppression automatique. Maximum 300 lignes par lot.'),
  E('div',{className:'csv-actions'},file,example,apply),output));
}
