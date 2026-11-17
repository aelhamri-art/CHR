/* Asset manager without third-party dependencies or local mock data. */
import * as api from './api.js';
const BUCKET='chr-product-media';
function el(tag,attrs={},...children){
 const n=document.createElement(tag);
 for(const [k,v] of Object.entries(attrs)){
  if(k==='className')n.className=v;
  else if(k==='onClick')n.addEventListener('click',v);
  else if(k==='onSubmit')n.addEventListener('submit',v);
  else if(k==='type')n.type=v;
  else if(k==='value')n.value=v;
  else if(k==='required')n.required=!!v;
  else if(k==='accept')n.accept=v;
  else n.setAttribute(k,String(v));
 }
 for(const c of children.flat())if(c!==null&&c!==undefined)n.append(c instanceof Node?c:document.createTextNode(String(c)));
 return n;
}
export async function mediaPage(storeId,onUpdated,notify){
 const [products,media]=await Promise.all([api.list('products',storeId),api.list('product_media',storeId,{limit:1000})]);
 const header=el('div',{className:'page-header'},el('div',{},
  el('div',{className:'eyebrow'},'CATALOGUE / MÉDIAS'),
  el('h1',{},'Images des produits'),
  el('p',{className:'lead'},'Fichiers réels, rattachés aux produits de votre entreprise.')));
 const page=el('div',{},header);
 if(!products.length){
  page.append(el('p',{className:'notice-inline'},'Crée un produit avant d’importer des images.'));return page;
 }
 const form=el('form',{className:'media-form'});
 const chosen=el('select',{},...products.map(p=>el('option',{value:p.id},p.title)));
 const file=el('input',{type:'file',accept:'image/jpeg,image/png,image/webp,image/avif',required:true});
 const alt=el('input',{placeholder:'Description accessible de la photo'});
 const button=el('button',{type:'submit',className:'btn accent'},'Importer la photo');
 form.append(
  el('label',{},'Produit',chosen),el('label',{},'Fichier image (max. 5 Mo)',file),
  el('label',{},'Texte alternatif',alt),button
 );
 form.addEventListener('submit',async ev=>{
  ev.preventDefault();button.disabled=true;
  const image=file.files?.[0],types=['image/jpeg','image/png','image/webp','image/avif'];
  if(!image||!types.includes(image.type)||image.size>5*1024*1024){button.disabled=false;return notify('Image invalide (JPEG, PNG, WebP, AVIF ; 5 Mo maximum).','error');}
  const extension={'image/jpeg':'.jpg','image/png':'.png','image/webp':'.webp','image/avif':'.avif'}[image.type];
  const path=storeId+'/'+chosen.value+'/'+crypto.randomUUID()+extension;
  let uploaded=false;
  try{
   await api.uploadPublicFile(BUCKET,path,image);uploaded=true;
   await api.insert('product_media',{store_id:storeId,product_id:chosen.value,storage_path:path,alt_text:alt.value.trim(),position:0});
   notify('Image importée et reliée au produit.','success');await onUpdated();
  }catch(err){
   if(uploaded)await api.deletePublicFile(BUCKET,path).catch(()=>{});
   notify(err.message,'error');
  }finally{button.disabled=false;}
 });
 page.append(el('section',{className:'panel'},el('h2',{},'Importer un visuel'),form));
 if(!media.length)page.append(el('section',{className:'panel'},el('p',{className:'muted'},'Aucune image enregistrée.')));
 else{
  const cards=el('div',{className:'media-grid'});
  for(const item of media){
   const product=products.find(p=>p.id===item.product_id);
   const image=el('img',{src:api.publicFileUrl(BUCKET,item.storage_path),alt:item.alt_text||'Photo produit',loading:'lazy'});
   const remove=el('button',{type:'button',className:'btn danger-btn',onClick:async()=>{
    if(!confirm('Supprimer cette image du catalogue ?'))return;
    try {
     await api.remove('product_media',item.id,storeId);
     await api.deletePublicFile(BUCKET,item.storage_path).catch(()=>notify('Fichier orphelin : nettoyage nécessaire.','error'));
     notify('Image retirée du produit.','success');await onUpdated();
    }catch(e){notify(e.message,'error');}
   }},'Supprimer');
   cards.append(el('div',{className:'media-card'},image,el('div',{className:'media-card-body'},
    el('strong',{},product?.title||'Produit retiré'),
    el('small',{},item.alt_text||'Aucune description'),remove)));
  }
  page.append(cards);
 }
 return page;
}
