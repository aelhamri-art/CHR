export function euro(minor,currency='EUR'){return new Intl.NumberFormat('fr-FR',{style:'currency',currency}).format(Number(minor||0)/100);}
export function number(value){return new Intl.NumberFormat('fr-FR').format(Number(value||0));}
export function escapeHtml(input){return String(input??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
export function clampQuantity(value){const n=Number(value);if(!Number.isInteger(n)||n<1||n>999)throw new Error('Quantité comprise entre 1 et 999.');return n;}
export function safePath(path){const value=String(path??'');return value.startsWith('/')&&!value.startsWith('//')?value:'/';}
export function firstName(email){return String(email||'Client').split('@')[0].slice(0,16);}
export function categoryName(value){return String(value||'Équipements').trim();}
export function debounce(fn,wait=150){let timeout;return (...args)=>{clearTimeout(timeout);timeout=setTimeout(()=>fn(...args),wait);};}
export function imageUrl(supabaseUrl,path){
 if(!path)return null;
 const segments=String(path).split('/');
 if(segments.some(seg=>seg==='..'||seg==='.'||seg===''))return null;
 const encoded=segments.map(encodeURIComponent).join('/');
 return String(supabaseUrl).replace(/\/$/,'')+'/storage/v1/object/public/chr-product-media/'+encoded;
}
export function canBuy(){return false;} // PSP not connected: never pretend checkout is live.
