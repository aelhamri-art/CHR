const cfg=globalThis.CHR_CONFIG||{};
const BASE=String(cfg.url||'').replace(/\/$/,'');
const KEY=String(cfg.publishableKey||'');
const SESSION_KEY='chr-storefront-customer-session';
let session=null;
try{session=JSON.parse(sessionStorage.getItem(SESSION_KEY)||'null');}catch{}
let refreshPromise=null;
export class StoreError extends Error {constructor(message,status=0){super(message);this.name='StoreError';this.status=status;}}
export function configured(){return /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(BASE)&&KEY.length>15;}
export function supabaseUrl(){return BASE;}
export function sessionInfo(){return session;}
function setSession(value){session=value;try{if(value)sessionStorage.setItem(SESSION_KEY,JSON.stringify(value));else sessionStorage.removeItem(SESSION_KEY);}catch{}}
function url(path,params){
 const u=new URL(BASE+path);
 for(const [k,v] of Object.entries(params||{})){if(v!==null&&v!==undefined)u.searchParams.set(k,String(v));}
 return u.toString();
}
async function call(path,{method='GET',body,params,headers={},authorized=true,retry=true}={}){
 if(!configured())throw new StoreError('Configuration Supabase absente.');
 const h={apikey:KEY,Accept:'application/json',...headers};
 if(authorized&&session?.access_token)h.Authorization='Bearer '+session.access_token;
 if(body!==undefined)h['Content-Type']='application/json';
 let response;
 try{response=await fetch(url(path,params),{method,headers:h,body:body!==undefined?JSON.stringify(body):undefined});}
 catch{throw new StoreError('Connexion indisponible. Vérifiez votre réseau.');}
 if(response.status===401&&authorized&&retry&&session?.refresh_token){
  try{await refresh();return call(path,{method,body,params,headers,authorized,retry:false});}
  catch{setSession(null);throw new StoreError('Session expirée. Veuillez vous reconnecter.',401);}
 }
 const raw=await response.text();let result;
 try{result=raw?JSON.parse(raw):null;}catch{result=raw;}
 if(!response.ok)throw new StoreError(result?.message||result?.msg||result?.error_description||result?.error||'Une erreur est survenue.',response.status);
 return result;
}
export async function refresh(){
 if(!session?.refresh_token)throw new StoreError('Aucune session.',401);
 if(refreshPromise)return refreshPromise;
 refreshPromise=call('/auth/v1/token?grant_type=refresh_token',{
  method:'POST',body:{refresh_token:session.refresh_token},authorized:false,retry:false
 }).then(result=>{if(!result.access_token)throw new StoreError('Session expirée.',401);setSession(result);return result;}).finally(()=>{refreshPromise=null;});
 return refreshPromise;
}
export async function signup(email,password){return call('/auth/v1/signup',{method:'POST',body:{email,password},authorized:false});}
export async function login(email,password){
 const result=await call('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password},authorized:false});
 if(!result?.access_token)throw new StoreError('Authentification incomplète.');
 setSession(result);return result;
}
export async function recover(email){return call('/auth/v1/recover',{method:'POST',body:{email},authorized:false});}
export async function user(){
 if(!session?.access_token)return null;
 try{return await call('/auth/v1/user');}
 catch(e){if(e.status===401)setSession(null);throw e;}
}
export async function logout(){try{if(session?.access_token)await call('/auth/v1/logout',{method:'POST'});}finally{setSession(null);}}
export async function settings(slug){
 const data=await call('/rest/v1/storefront_settings',{params:{public_slug:'eq.'+slug,select:'store_id,public_slug,brand_name,eyebrow,headline,subline,contact_email,hero_image_path,published,legal_notice,privacy_policy,terms_of_sale',limit:1}});
 return data?.[0]||null;
}
/** Bounded, RLS-enforced catalog API: never download the entire product database. */
export async function catalogPage(slug,{query='',category=null,sort='name',cursor=null,limit=24}={}){
 const q=String(query).trim();
 if(q.length>120)throw new StoreError('Recherche trop longue.');
 const data=await call('/rest/v1/rpc/chr_catalog_page',{method:'POST',body:{
  p_slug:slug,p_query:q,p_category:category,p_sort:sort,
  p_cursor_title:cursor?.title??null,p_cursor_price:cursor?.price??null,
  p_cursor_id:cursor?.id??null,p_limit:Math.min(48,Math.max(1,Number(limit)||24))
 }});
 return {items:Array.isArray(data?.items)?data.items:[],has_more:!!data?.has_more,next_cursor:data?.next_cursor??null};
}
export async function catalog(storeId,slug='chr'){
 if(!storeId)return [];
 return (await catalogPage(slug,{limit:12})).items;
}
export async function catalogSuggestions(slug,query){
 const q=String(query).trim();
 if(q.length<2)return [];
 if(q.length>80)throw new StoreError('Recherche trop longue.');
 const data=await call('/rest/v1/rpc/chr_catalog_suggest',{method:'POST',body:{p_slug:slug,p_query:q,p_limit:5}});
 return Array.isArray(data)?data:[];
}
export async function catalogCategories(slug){
 const data=await call('/rest/v1/rpc/chr_catalog_categories',{method:'POST',body:{p_slug:slug}});
 return Array.isArray(data)?data:[];
}
export async function catalogProduct(slug,handle){
 if(!handle||String(handle).length>180)return [];
 const data=await call('/rest/v1/rpc/chr_catalog_product',{method:'POST',body:{p_slug:slug,p_handle:handle}});
 return Array.isArray(data)?data:[];
}
export async function catalogCartLines(slug,ids){
 if(!Array.isArray(ids)||!ids.length)return [];
 if(ids.length>100)throw new StoreError('100 références maximum dans une sélection.');
 const data=await call('/rest/v1/rpc/chr_catalog_cart_lines',{method:'POST',body:{p_slug:slug,p_ids:ids}});
 return Array.isArray(data)?data:[];
}
export async function profile(storeId){
 const data=await call('/rest/v1/storefront_customers',{params:{store_id:'eq.'+storeId,select:'*',limit:1}});
 return data?.[0]||null;
}
export async function saveProfile(storeId,userId,patch){
 const value={...patch,store_id:storeId,user_id:userId};
 const data=await call('/rest/v1/storefront_customers',{method:'POST',params:{on_conflict:'store_id,user_id'},headers:{Prefer:'resolution=merge-duplicates,return=representation'},body:value});
 return data?.[0]||null;
}
export async function addresses(storeId){
 return call('/rest/v1/storefront_addresses',{params:{store_id:'eq.'+storeId,select:'*',order:'created_at.desc',limit:100}});
}
export async function addAddress(storeId,userId,address){
 const data=await call('/rest/v1/storefront_addresses',{method:'POST',headers:{Prefer:'return=representation'},body:{...address,store_id:storeId,user_id:userId}});
 return data?.[0]||null;
}
export async function deleteAddress(storeId,id){
 return call('/rest/v1/storefront_addresses',{method:'DELETE',params:{store_id:'eq.'+storeId,id:'eq.'+id},headers:{Prefer:'return=representation'}});
}
export async function wishlist(storeId){return call('/rest/v1/storefront_wishlist',{params:{store_id:'eq.'+storeId,select:'variant_id,created_at'}});}
export async function addWish(storeId,userId,variantId){
 return call('/rest/v1/storefront_wishlist',{method:'POST',body:{store_id:storeId,user_id:userId,variant_id:variantId},headers:{Prefer:'resolution=ignore-duplicates'},params:{on_conflict:'store_id,user_id,variant_id'}});
}
export async function removeWish(storeId,variantId){
 return call('/rest/v1/storefront_wishlist',{method:'DELETE',params:{store_id:'eq.'+storeId,variant_id:'eq.'+variantId}});
}
export async function savedCart(storeId){return call('/rest/v1/storefront_saved_cart',{params:{store_id:'eq.'+storeId,select:'variant_id,quantity'}});}
export async function saveCartLine(storeId,userId,variantId,quantity){
 if(quantity===0)return call('/rest/v1/storefront_saved_cart',{method:'DELETE',params:{store_id:'eq.'+storeId,variant_id:'eq.'+variantId}});
 return call('/rest/v1/storefront_saved_cart',{method:'POST',params:{on_conflict:'store_id,user_id,variant_id'},headers:{Prefer:'resolution=merge-duplicates'},body:{store_id:storeId,user_id:userId,variant_id:variantId,quantity}});
}
export async function quotes(storeId){return call('/rest/v1/storefront_quotes',{params:{store_id:'eq.'+storeId,select:'id,estimate_minor,status,created_at,lines',order:'created_at.desc',limit:50}});}
export async function requestQuote(storeId,lines,company,email,notes,key){
 return call('/rest/v1/rpc/request_storefront_quote',{method:'POST',body:{
 p_store_id:storeId,p_lines:lines.map(x=>({variant_id:x.variant_id,quantity:x.quantity})),
 p_company:company,p_email:email,p_notes:notes,p_key:key
 }});
}
