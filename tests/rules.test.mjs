import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {parseMoney,parseInteger,slugify,listText,escapeCsv,exportCsv,jsonInput} from '../src/rules.js';
test('monnaie exacte sans flottants',()=> {
 assert.equal(parseMoney('79,99'),7999);
 assert.equal(parseMoney('80'),8000);
 assert.equal(parseMoney('80.01'),8001);
 assert.equal(parseMoney('0.05'),5);
 assert.throws(()=>parseMoney('-2'));
 assert.throws(()=>parseMoney('1.001'));
 assert.throws(()=>parseMoney('NaN'));
});
test('poids et quantités bornés',()=> {
 assert.equal(parseInteger('1500'),1500);
 assert.throws(()=>parseInteger('1.5'));
 assert.throws(()=>parseInteger('-1'));
 assert.throws(()=>parseInteger('100000001'));
});
test('slugs et listes',()=>{
 assert.equal(slugify('Four à convection CHR !'),'four-a-convection-chr');
 assert.deepEqual(listText('FR, BE, FR, LU'),['FR','BE','LU']);
});
test('export CSV sûr',()=>{
 assert.equal(escapeCsv('=1+2'),'"\\'=1+2"');
 const csv=exportCsv([{name:'="X"',price_minor:900}],['name','price_minor']);
 assert.match(csv,/'\\"\\"X\\"\\"/);
});
test('JSON validé',()=>{
 assert.deepEqual(jsonInput('{"rate":20}'),{rate:20});
 assert.throws(()=>jsonInput('[]'));
 assert.throws(()=>jsonInput('{"bad":}'));
});
