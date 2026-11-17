/* Fonctions métier pures et testables. La base reste l'autorité pour les transactions. */
export function parseMoney(input) {
  const raw = String(input??'').trim().replace(',','.');
  if (!/^\d{1,12}(\.\d{1,2})?$/.test(raw)) throw new Error('Montant invalide (2 décimales maximum).');
  const [euros,cents=''] = raw.split('.');
  const result = Number(euros)*100 + Number(cents.padEnd(2,'0'));
  if (!Number.isSafeInteger(result) || result<0) throw new Error('Montant hors limites.');
  return result;
}
export function formatMoney(minor,currency='EUR') {
  return new Intl.NumberFormat('fr-FR',{style:'currency',currency}).format(Number(minor||0)/100);
}
export function parseInteger(input,{min=0,max=100000000}={}) {
  const s=String(input??'').trim();
  if (!/^-?\d+$/.test(s)) throw new Error('Nombre entier obligatoire.');
  const n=Number(s);
  if (!Number.isSafeInteger(n)||n<min||n>max) throw new Error('Nombre hors limites ['+min+' ; '+max+'].');
  return n;
}
export function listText(input) {return [...new Set(String(input||'').split(',').map(s=>s.trim()).filter(Boolean))];}
export function textList(items) {return Array.isArray(items)?items.join(', '):'';}
export function jsonInput(input,expected='object') {
  const value=JSON.parse(String(input|| (expected==='array'?'[]':'{}')));
  if (expected==='array' && !Array.isArray(value)) throw new Error('Liste JSON attendue.');
  if (expected==='object' && (value===null||typeof value!=='object'||Array.isArray(value))) throw new Error('Objet JSON attendu.');
  return value;
}
export function slugify(s) {
 return String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,63);
}
export function escapeCsv(s) {
 const v=String(s??'');
 // Neutralise aussi les formules lors de l'ouverture dans Excel.
 const safe=/^[=+\-@\t\r]/.test(v)?"'"+v:v;
 return '"'+safe.replaceAll('"','""')+'"';
}
export function exportCsv(rows,columns) {
 return [columns.map(escapeCsv).join(','),...rows.map(row=>columns.map(k=>escapeCsv(typeof row[k]==='object'?JSON.stringify(row[k]):row[k])).join(','))].join('\r\n');
}
export function validateShippingCandidate(context,candidate) {
 if (!candidate) return false;
 if (!context || context.weightGrams<0 || context.subtotalMinor<0) return false;
 return true;
}
