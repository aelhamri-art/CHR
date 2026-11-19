import {clampQuantity} from './format.js';
export class Cart {
 constructor(slug='chr',storage=globalThis.localStorage) {
  this.key='chr-customer-cart:'+slug;
  this.storage=storage;
  this.subscribers=new Set();
  try{const raw=JSON.parse(storage.getItem(this.key)||'{}');this.items=Object.fromEntries(
   Object.entries(raw).filter(([id,q])=>/^[a-f0-9-]{36}$/i.test(id)&&Number.isInteger(q)&&q>0&&q<=999).slice(0,100));
  }catch{this.items={};}
 }
 subscribe(listener){this.subscribers.add(listener);return()=>this.subscribers.delete(listener);}
 emit(){try{this.storage.setItem(this.key,JSON.stringify(this.items));}catch{}this.subscribers.forEach(fn=>fn(this.items));}
 add(id,quantity=1){if(!this.items[id]&&Object.keys(this.items).length>=100)throw new Error('100 références maximum dans le panier.');const q=clampQuantity(quantity);this.items[id]=Math.min(999,(this.items[id]||0)+q);this.emit();}
 set(id,quantity){const n=Number(quantity);if(n===0){this.remove(id);return;}this.items[id]=clampQuantity(n);this.emit();}
 remove(id){delete this.items[id];this.emit();}
 clear(){this.items={};this.emit();}
 count(){return Object.values(this.items).reduce((a,b)=>a+b,0);}
 lines(catalog){const byId=new Map(catalog.map(p=>[p.variant_id,p]));return Object.entries(this.items)
  .map(([id,quantity])=>({product:byId.get(id),variant_id:id,quantity}))
  .filter(line=>!!line.product);}
 subtotal(catalog){return this.lines(catalog).reduce((a,line)=>a+line.product.price_minor*line.quantity,0);}
 prune(catalog){
  const valid=new Set(catalog.map(x=>x.variant_id));
  let changed=false;
  for(const id of Object.keys(this.items))if(!valid.has(id)){delete this.items[id];changed=true;}
  if(changed)this.emit();
  return changed;
 }
 merge(values){for(const [id,quantity] of Object.entries(values||{})){if(Object.keys(this.items).length>=100&&!this.items[id])break;if(/^[a-f0-9-]{36}$/i.test(id))this.items[id]=Math.min(999,Math.max(this.items[id]||0,clampQuantity(quantity)));}this.emit();}
}
