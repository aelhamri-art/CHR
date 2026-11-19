// Execute ONLY with k6 and on an ISOLATED CHR STAGING project with >=100k synthetic SKUs.
// Usage:
//   STAGING_URL=https://<staging>.supabase.co STAGING_ANON_KEY=<publishable>
//   STAGING_SLUG=chr-staging STAGING_EMAIL=test@staging.invalid STAGING_PASSWORD=<staging test password>
//   ALLOW_CHR_STAGING_LOAD=YES k6 run benchmarks/100k/catalog.k6.js
import http from 'k6/http';
import {check,sleep} from 'k6';
import {Rate} from 'k6/metrics';
export const functionalFailure=new Rate('chr_functional_failure');
const url=__ENV.STAGING_URL||'';
const key=__ENV.STAGING_ANON_KEY||'';
const slug=__ENV.STAGING_SLUG||'chr-staging';
const testEmail=__ENV.STAGING_EMAIL||'';
const testPassword=__ENV.STAGING_PASSWORD||'';
const publicMode=__ENV.STAGING_PUBLIC==='YES';
if(__ENV.ALLOW_CHR_STAGING_LOAD!=='YES'||!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(url)
 ||url.includes('dkisxdquvryoddpphgeg')||key.length<18
 ||!/^chr-staging(?:-[a-z0-9-]{2,25})?$/.test(slug)
 ||(!publicMode&&(!testEmail.includes('@')||!testPassword))){
 throw new Error('Refusing load test: explicit isolated staging Supabase credentials required.');
}
export const options={
 scenarios:{
  catalog_load:{executor:'ramping-vus',
   stages:[{duration:'30s',target:5},{duration:'2m',target:15},{duration:'2m',target:30},{duration:'30s',target:0}],
   gracefulRampDown:'20s'}
 },
 thresholds:{
  'http_req_failed':['rate<0.005'],
  'http_req_duration':['p(95)<500'],
  'chr_functional_failure':['rate<0.005'],
 },
 discardResponseBodies:false,
};
const publicHeaders={apikey:key,'Content-Type':'application/json',Accept:'application/json'};
export function setup(){
 let authorization;
 if(!publicMode){
  const res=http.post(url+'/auth/v1/token?grant_type=password',
   JSON.stringify({email:testEmail,password:testPassword}),{headers:publicHeaders});
  if(res.status!==200||!res.json('access_token'))throw new Error('Staging account login failed.');
  authorization='Bearer '+res.json('access_token');
 }
 const headers={...publicHeaders,...(authorization?{Authorization:authorization}:{})};
 const probe=http.post(url+'/rest/v1/rpc/chr_catalog_page',
  JSON.stringify({p_slug:slug,p_limit:2}),{headers});
 if(probe.status!==200||!Array.isArray(probe.json('items'))||probe.json('items').length===0)
  throw new Error('REFUSED: empty or unpublished fixture catalog. Benchmark would be meaningless.');
 return {authorization};
}
export default function(data){
 const optionsApi={headers:{...publicHeaders,...(data.authorization?{Authorization:data.authorization}:{})}};

const samples=['four','réfrigérateur','inox','friteuse','cuisson','HOTTE-'];
 const selection=__VU%4;
 let rpc,body;
 if(selection===0){rpc='chr_catalog_page';body={p_slug:slug,p_limit:24,p_sort:'name'};}
 else if(selection===1){rpc='chr_catalog_page';body={p_slug:slug,p_limit:24,p_sort:'price-low',p_query:samples[__ITER%samples.length]};}
 else if(selection===2){rpc='chr_catalog_suggest';body={p_slug:slug,p_query:samples[__ITER%samples.length],p_limit:5};}
 else{rpc='chr_catalog_categories';body={p_slug:slug};}
 const response=http.post(url+'/rest/v1/rpc/'+rpc,JSON.stringify(body),optionsApi);
 const correct=check(response,{
  'HTTP 200':r=>r.status===200,
  'valid JSON':r=>{try{const x=r.json();return x!==null;}catch{return false;}},
  'bounded page':r=>{
   if(rpc!=='chr_catalog_page'||r.status!==200)return true;
   const result=r.json();return Array.isArray(result.items)&&result.items.length<=24;
  }
 });
 functionalFailure.add(!correct);
 sleep(0.2+Math.random()*0.6);
}
