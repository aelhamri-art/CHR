import {test} from 'node:test';
import assert from 'node:assert/strict';
import {Cart} from '../storefront/src/cart.js';
import {clampQuantity,escapeHtml,imageUrl,euro} from '../storefront/src/format.js';

function storage(){
 const mem=new Map();
 return {getItem:key=>mem.get(key)||null,setItem:(k,v)=>mem.set(k,v),removeItem:key=>mem.delete(key)};
}
const ID1='8aaab66c-3cd2-4dc6-9e42-f2253bf361bf';
const ID2='ce21987c-65da-4c2d-a638-b585010281dc';
test('cart is persistent, quantity limited, no invalid IDs on restore',()=>{
 const mem=storage(),cart=new Cart('chr-test',mem);
 cart.add(ID1,2);cart.add(ID1,1);cart.add(ID2,3);
 assert.equal(cart.count(),6);
 const restored=new Cart('chr-test',mem);
 assert.deepEqual(restored.items,{[ID1]:3,[ID2]:3});
 restored.set(ID1,0);
 assert.equal(restored.count(),3);
 assert.throws(()=>restored.add(ID1,0));
 assert.throws(()=>restored.set(ID2,1000));
});
test('cart subtotal trusts only current published catalog prices, not stored price',()=>{
 const mem=storage(),cart=new Cart('chr-test',mem);
 cart.add(ID1,2);
 const items=[{variant_id:ID1,price_minor:7999,product_id:'p'},{variant_id:ID2,price_minor:100000}];
 assert.equal(cart.subtotal(items),15998);
 assert.equal(cart.subtotal([]),0);
});
test('quantities must be exact integer from 1 to 999',()=>{
 assert.equal(clampQuantity('3'),3);
 assert.throws(()=>clampQuantity('-1'));
 assert.throws(()=>clampQuantity('1.5'));
 assert.throws(()=>clampQuantity('1000'));
});
test('escaping product text and safe product imagery paths',()=>{
 assert.equal(escapeHtml('<img src=x onerror="alert(1)">'),'&lt;img src=x onerror=&quot;alert(1)&quot;&gt;');
 assert.equal(imageUrl('https://xxx.supabase.co','store/product/photo.webp'),
 'https://xxx.supabase.co/storage/v1/object/public/chr-product-media/store/product/photo.webp');
 assert.equal(imageUrl('https://xxx.supabase.co','../secret.png'),null);
 assert.equal(imageUrl('https://xxx.supabase.co','https://evil.example/img'),null);
});
test('currency shows EUR from minor units',()=>{
 assert.match(euro(129000),/1[\s\u00A0\u202F]?290,00/);
});

test('withdrawn products are removed from saved cart on published catalog refresh',()=>{
 const mem=storage(),cart=new Cart('withdrawn',mem);
 cart.add(ID1,2);cart.add(ID2,1);
 assert.equal(cart.prune([{variant_id:ID2}]),true);
 assert.deepEqual(cart.items,{[ID2]:1});
 assert.equal(cart.prune([{variant_id:ID2}]),false);
});
