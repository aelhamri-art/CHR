#!/usr/bin/env node
/**
 * CHR staging-only 100k SKU loader. Uses the existing RLS-guarded import RPC,
 * and refuses the actual CHR production project reference unconditionally.
 *
 * Env (never commit credentials):
 * ALLOW_CHR_STAGING_SEED=I_UNDERSTAND_STAGING_ONLY
 * STAGING_URL=https://<isolated-ref>.supabase.co
 * STAGING_ANON_KEY=<public key>
 * STAGING_STORE_ID=<uuid for a test store only>
 * STAGING_EMAIL=<test admin email>
 * STAGING_PASSWORD=<test admin password>
 * STAGING_SLUG=chr-staging
 * STAGING_SEED_COUNT=100000 (default, optional, maximum 100000)
 *
 * This file does not change any data unless executed explicitly with all
 * separate-staging credentials. It never calls the production CHR database.
 */
import {createHash} from 'node:crypto';

const PROD_REF='dkisxdquvryoddpphgeg';
const url=String(process.env.STAGING_URL||'').replace(/\/$/,'');
const key=process.env.STAGING_ANON_KEY||'';
const storeId=process.env.STAGING_STORE_ID||'';
const slug=process.env.STAGING_SLUG||'chr-staging';
const email=process.env.STAGING_EMAIL||'';
const password=process.env.STAGING_PASSWORD||'';
const limit=Number(process.env.STAGING_SEED_COUNT||100000);
const allowed=process.env.ALLOW_CHR_STAGING_SEED==='I_UNDERSTAND_STAGING_ONLY';
if(!allowed||!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url)
||url.includes(PROD_REF)||!/^[0-9a-fA-F-]{36}$/.test(storeId)
||key.length<15||!email.includes('@')||!password
||!/^chr-staging(?:-[a-z0-9-]{2,25})?$/.test(slug)
||!Number.isInteger(limit)||limit<1||limit>100000){
 console.error('REFUSED: isolated staging project, valid test credentials and explicit guard required.');
 process.exit(2);
}

const types=['Four mixte','Four convection','Armoire froide','Réfrigérateur',
 'Table inox','Lave-vaisselle','Friteuse','Hotte','Plancha','Batteur','Vitrine froide',
 'Congélateur','Coupe-légumes','Chariot inox','Machine à glace','Lave-verres',
 'Cellule de refroidissement','Laminoir','Rôtissoire','Meuble plonge'];
const categories=['Fours','Cuisson','Froid positif','Froid négatif','Inox','Laverie','Préparation','Ventilation','Buffet','Boulangerie','Pâtisserie','Conditionnement','Service','Stockage','Hygiène','Mobilier','Glacerie','Rôtisserie','Boissons','Accessoires'];

const uuid=(value)=>{
 const hash=createHash('sha256').update('CHR STAGING ONLY 100K V2:'+storeId+':'+value).digest('hex');
 return [hash.slice(0,8),hash.slice(8,12),'4'+hash.slice(13,16),'8'+hash.slice(17,20),hash.slice(20,32)].join('-');
};
function row(n){
 const parent=Math.floor((n-1)/10)+1;
 const variant=((n-1)%10)+1;
 const kind=types[parent%types.length];
 return {
  handle:'stage-chr-v2-'+String(parent).padStart(6,'0'),
  title:kind+' — Performance '+String(2026+parent%27),
  vendor:'Fournisseur test '+String(parent%100).padStart(3,'0'),
  category:categories[parent%categories.length],
  sku:'CHR-STAGE-V2-'+String(n).padStart(6,'0'),
  variant_title:'Modèle '+variant,
  price_minor:5000+(n%1999)*125,
  weight_grams:500+(n%800)*250,
  status:'active'
 };
}
let auth=null;
async function send(path,body,authorized=true){
 const result=await fetch(url+path,{
  method:'POST',
  headers:{apikey:key,'Content-Type':'application/json',Accept:'application/json',
   ...(authorized&&auth?.access_token?{Authorization:'Bearer '+auth.access_token}:{})},
  body:JSON.stringify(body),
  signal:AbortSignal.timeout(55000)
 });
 let value;
 try{value=await result.json();}catch{value=null;}
 return {status:result.status,ok:result.ok,data:value};
}
async function signIn(){
 const r=await send('/auth/v1/token?grant_type=password',{email,password},false);
 if(!r.ok||!r.data?.access_token||!r.data?.refresh_token)
  throw new Error('Staging authentication refused ('+r.status+').');
 auth=r.data;
}
async function refresh(){
 const r=await send('/auth/v1/token?grant_type=refresh_token',{refresh_token:auth.refresh_token},false);
 if(!r.ok||!r.data?.access_token)throw new Error('Staging session expired.');
 auth=r.data;
}
async function ensureUnpublishedStagingSettings(){
 const endpoint=url+'/rest/v1/storefront_settings?store_id=eq.'+storeId+'&select=store_id,public_slug,published&limit=1';
 const headers={apikey:key,Authorization:'Bearer '+auth.access_token,Accept:'application/json'};
 const existing=await fetch(endpoint,{headers,signal:AbortSignal.timeout(20000)});
 if(!existing.ok)throw new Error('Storefront settings preflight failed ('+existing.status+').');
 const records=await existing.json();
 if(records.length){
  if(records[0].published||records[0].public_slug!==slug)
   throw new Error('REFUSED: staging store already published or linked to a different slug.');
  return;
 }
 const created=await fetch(url+'/rest/v1/storefront_settings',{
  method:'POST',
  headers:{...headers,'Content-Type':'application/json',Prefer:'return=representation'},
  body:JSON.stringify({store_id:storeId,public_slug:slug,published:false}),
  signal:AbortSignal.timeout(20000)
 });
 if(!created.ok)throw new Error('Cannot create unpublished staging settings: '+created.status);
}

async function importBatch(start,rows){
 const body={p_store_id:storeId,p_rows:rows,p_idempotency_key:uuid(start)};
 for(let attempt=0;attempt<5;attempt++){
  let r;
  try{r=await send('/rest/v1/rpc/import_products_batch',body);}
  catch(error){
   if(attempt===4)throw error;
   await new Promise(res=>setTimeout(res,(attempt+1)*1500));
   continue;
  }
  if(r.status===401&&attempt<4){await refresh();continue;}
  if([429,500,502,503,504].includes(r.status)&&attempt<4){
   await new Promise(res=>setTimeout(res,(attempt+1)*1500));
   continue;
  }
  if(!r.ok)throw new Error('Batch '+start+' rejected (HTTP '+r.status+'): '+String(r.data?.message||'Invalid data').slice(0,180));
  if(!['imported','already_imported'].includes(r.data?.status)||Number(r.data?.count)!==rows.length){
   throw new Error('Unexpected import confirmation for batch '+start);
  }
  return r.data.status;
 }
 throw new Error('Retry budget exceeded for batch '+start);
}
async function total(table){
 const res=await fetch(url+'/rest/v1/'+table+'?store_id=eq.'+storeId+'&select=id&limit=1',{
  headers:{apikey:key,Authorization:'Bearer '+auth.access_token,Prefer:'count=exact'},
  signal:AbortSignal.timeout(55000)
 });
 if(!res.ok)throw new Error('Unable to confirm '+table+' count: '+res.status);
 const raw=res.headers.get('content-range')||'';
 const match=raw.match(/\/(\d+)$/);
 if(!match)throw new Error('Missing exact Content-Range for '+table);
 return Number(match[1]);
}
await signIn();
await ensureUnpublishedStagingSettings();
console.error('Staging-only identity authenticated. Starting synthetic fixture load.');
let imported=0,already=0;
for(let start=1;start<=limit;start+=300){
 const rows=Array.from({length:Math.min(300,limit-start+1)},(_,index)=>row(start+index));
 const status=await importBatch(start,rows);
 if(status==='already_imported')already+=rows.length;
 else imported+=rows.length;
 if(start===1||start%3000===1||start+rows.length>limit)
   console.error('Progress: '+Math.min(start+rows.length-1,limit)+'/'+limit+' staged references');
}
const productCount=await total('products');
const variantCount=await total('product_variants');
if(productCount<Math.ceil(limit/10)||variantCount<limit)
 throw new Error('Post-load integrity failure: fewer than '+limit+' products or variants.');
console.log(JSON.stringify({
 source:'isolated Supabase staging (NOT CHR production)',
 generated:limit,expected_parent_products:Math.ceil(limit/10),created_or_updated:imported,already_imported:already,
 totals:{products:productCount,variants:variantCount},
 production_untouched:true
},null,2));
