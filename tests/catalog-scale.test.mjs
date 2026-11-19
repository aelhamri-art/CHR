import {test} from 'node:test';
import assert from 'node:assert/strict';

// These tests stub the HTTP transport. They do not certify Supabase RLS or load capacity.
globalThis.CHR_CONFIG={url:'https://dkisxdquvryoddpphgeg.supabase.co',publishableKey:'sb_publishable_TEST_PUBLIC_ONLY_123'};
const api=await import('../storefront/src/api.js');
const requests=[];
globalThis.fetch=async (url,init={})=>{
 const body=JSON.parse(init.body||'{}');
 requests.push({url:String(url),body,method:init.method});
 let value;
 if(String(url).endsWith('/chr_catalog_page')){
  value={items:[{variant_id:'a',title:'Four professionnel'}],has_more:true,next_cursor:{title:'Four professionnel',price:150000,id:'11111111-1111-4111-8111-111111111111'}};
 }else if(String(url).endsWith('/chr_catalog_suggest')){
  value=[{variant_id:'a',title:'Four professionnel'}];
 }else if(String(url).endsWith('/chr_catalog_cart_lines')){
  value=[{variant_id:body.p_ids[0],price_minor:14900}];
 }else if(String(url).endsWith('/chr_catalog_product')){value=[{variant_id:'a',title:'Four professionnel'}];}
 else{value=[];}
 return {ok:true,status:200,text:async()=>JSON.stringify(value)};
};
test('pagination is a bounded RPC request, never 1000-item client download',async()=>{
 requests.length=0;
 const page=await api.catalogPage('chr',{query:'four',limit:500,sort:'price-high',cursor:{title:'X',price:99999,id:'11111111-1111-4111-8111-111111111111'}});
 assert.equal(page.has_more,true);
 assert.equal(page.items.length,1);
 assert.equal(requests[0].body.p_limit,48);
 assert.equal(requests[0].body.p_cursor_price,99999);
 assert.equal(requests[0].body.p_sort,'price-high');
 assert.match(requests[0].url,/\/rpc\/chr_catalog_page$/);
 assert.ok(!requests[0].url.includes('storefront_catalog?select'));
});
test('search suggestions use server RPC, with 2-char minimum',async()=>{
 requests.length=0;
 assert.deepEqual(await api.catalogSuggestions('chr','f'),[]);
 assert.equal(requests.length,0);
 const suggestions=await api.catalogSuggestions('chr','four');
 assert.equal(suggestions.length,1);
 assert.equal(requests[0].body.p_limit,5);
 assert.throws(()=>api.catalogSuggestions('chr','x'.repeat(90)),/Recherche trop longue/);
});
test('cart reference fetch asks for exactly selected IDs, never catalog subset',async()=>{
 requests.length=0;
 const ids=['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'];
 const lines=await api.catalogCartLines('chr',ids);
 assert.equal(lines.length,1);
 assert.deepEqual(requests[0].body.p_ids,ids);
 await assert.rejects(()=>api.catalogCartLines('chr',Array(101).fill(ids[0])),/100 références/);
});
