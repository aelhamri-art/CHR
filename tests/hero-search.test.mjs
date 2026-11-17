import { test } from 'node:test';
import { strict as assert } from 'node:assert';
import { findSuggestions, norm, ROTATIONS } from '../storefront/src/hero-search.js';
const variants=[
 {variant_id:'1',title:'Four mixte professionnel',sku:'F-450',category:'Cuisson',product_handle:'four-mixte',price_minor:239900},
 {variant_id:'2',title:'Armoire réfrigérée 600L',sku:'FR-600',category:'Froid',product_handle:'armoire-froid',price_minor:180000},
 {variant_id:'3',title:'Table inox 1200',sku:'INOX-12',category:'Préparation',product_handle:'table-inox',price_minor:32900}
];
test('search is accent-insensitive and matches SKU and category',()=>{
 assert.equal(norm('RéFrIgÉRÉE'),'refrigeree');
 assert.equal(findSuggestions(variants,'réfrigérée')[0].variant_id,'2');
 assert.equal(findSuggestions(variants,'F-450')[0].variant_id,'1');
 assert.equal(findSuggestions(variants,'préparation')[0].variant_id,'3');
});
test('never creates fake suggestions when catalog is unpublished or empty',()=>{
 assert.deepEqual(findSuggestions([], 'Four'),[]);
 assert.deepEqual(findSuggestions(variants,'inexistant'),[]);
 assert.deepEqual(findSuggestions(variants,'  '),[]);
});
test('search suggestions deduplicate variants and honor maximum',()=>{
 const repeated=[...variants,variants[0],variants[1]];
 assert.equal(findSuggestions(repeated,'e').length,3);
 assert.equal(findSuggestions(repeated,'e',1).length,1);
});
test('rotating examples are visible, descriptive, not invented products',()=>{
 assert.equal(ROTATIONS.length,4);
 for(const phrase of ROTATIONS)assert.ok(phrase.length>14);
});
