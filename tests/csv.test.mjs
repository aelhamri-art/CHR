import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {parseCsv,catalogFromCsv} from '../src/csv.js';
test('quoted CSV values',()=>{
 assert.deepEqual(parseCsv('Handle,Title\nh,"Four, mixte"\n'),[['Handle','Title'],['h','Four, mixte']]);
 assert.deepEqual(parseCsv('a,b\r\n"say ""yes""",3'),[['a','b'],['say "yes"','3']]);
});
test('Shopify-like import mapping',()=>{
 const items=catalogFromCsv('Handle,Title,Vendor,Variant SKU,Variant Price,Variant Grams,Published\nh,Four,V,FOUR1,80.01,4000,TRUE');
 assert.equal(items.length,1);assert.equal(items[0].price_minor,8001);
 assert.equal(items[0].weight_grams,4000);assert.equal(items[0].status,'active');
});
test('strict import validation',()=>{
 assert.throws(()=>catalogFromCsv('Handle,Title,SKU,price_eur\nx,Produit,SKU,1.234'));
 assert.throws(()=>catalogFromCsv('Handle,Title,SKU,price_eur\nx,Produit,SKU,10\nx,Produit,SKU,10'));
 assert.throws(()=>parseCsv('"unterminated'));
});

test('supplier category maps from CSV without changing status/price',()=>{
 const rows=catalogFromCsv('Handle,Title,Vendor,Category,Variant SKU,Variant Price,Variant Grams,Published\nfour-x,Four mixte,CHR,Cuisson,FOUR-X,1200.00,7000,TRUE');
 assert.equal(rows.length,1);
 assert.equal(rows[0].category,'Cuisson');
 assert.equal(rows[0].price_minor,120000);
 assert.equal(rows[0].status,'active');
});
