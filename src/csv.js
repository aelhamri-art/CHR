/* RFC4180-style UTF-8 CSV parser. Never eval supplier input. */
import {parseMoney,parseInteger,slugify} from './rules.js';
export function parseCsv(input) {
 const source=String(input||'').replace(/^\uFEFF/,'');
 const rows=[],row=[];let value='',quoted=false;
 for(let i=0;i<source.length;i++){
  const c=source[i];
  if(quoted){
   if(c==='"'&&source[i+1]==='"'){value+='"';i++;}
   else if(c==='"')quoted=false;
   else value+=c;
  }else if(c==='"'&&value==='')quoted=true;
  else if(c===','){row.push(value);value='';}
  else if(c==='\r'||c==='\n'){
   if(c==='\r'&&source[i+1]==='\n')i++;
   row.push(value);value='';
   if(row.some(cell=>cell!==''))rows.push(row.splice(0));
   else row.length=0;
  }else value+=c;
 }
 if(quoted)throw new Error('CSV invalide : guillemets non terminés.');
 row.push(value);if(row.some(cell=>cell!==''))rows.push(row);
 return rows;
}
function first(obj,names){for(const name of names)if(obj[name]!==undefined)return obj[name];return '';}
export function catalogFromCsv(source) {
 const rows=parseCsv(source);
 if(rows.length<2)throw new Error('CSV vide ou sans données.');
 const headers=rows.shift().map(h=>h.trim().toLowerCase());
 if(new Set(headers).size!==headers.length)throw new Error('Colonnes en double.');
 const required=[['handle'],['title'],['sku','variant sku'],['price_eur','variant price']];
 for(const group of required)if(!group.some(key=>headers.includes(key)))throw new Error('Colonne obligatoire absente : '+group.join(' ou '));
 if(rows.length>300)throw new Error('Maximum 300 lignes par import ; fractionne ton fichier.');
 const records=[];
 for(const [index,values] of rows.entries()){
  if(values.length!==headers.length)throw new Error('Ligne '+(index+2)+' : nombre de colonnes incorrect.');
  const obj=Object.fromEntries(headers.map((key,i)=>[key,values[i].trim()]));
  const title=first(obj,['title']);
  const handle=slugify(first(obj,['handle'])||title);
  const sku=first(obj,['sku','variant sku']);
  const rawPrice=first(obj,['price_eur','variant price']);
  const weight=first(obj,['weight_g','variant grams'])||'0';
  const published=first(obj,['published']);
  const status=first(obj,['status'])||((/^(true|1|oui)$/i.test(published))?'active':'draft');
  if(!handle||title.length<2||!sku)throw new Error('Ligne '+(index+2)+' : nom, handle ou SKU invalide.');
  if(!['draft','active','archived'].includes(status))throw new Error('Ligne '+(index+2)+' : statut invalide.');
  const record={handle,title,vendor:first(obj,['vendor']),category:first(obj,['category','product type','type']),sku,
   variant_title:first(obj,['variant_title','option1 value'])||'Par défaut',
   price_minor:parseMoney(rawPrice),weight_grams:parseInteger(weight),status};
  records.push(record);
 }
 const skus=records.map(r=>r.sku);
 if(new Set(skus).size!==skus.length)throw new Error('SKU en double dans le fichier : corrige avant import.');
 return records;
}
