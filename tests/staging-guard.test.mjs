import {test} from 'node:test';
import {strict as assert} from 'node:assert';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {resolve,dirname} from 'node:path';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const loader=resolve(root,'benchmarks/100k/seed-staging.mjs');
const base={
 ALLOW_CHR_STAGING_SEED:'I_UNDERSTAND_STAGING_ONLY',
 STAGING_ANON_KEY:'sb_publishable_FAKE_TEST_KEY_NOT_A_SECRET',
 STAGING_STORE_ID:'11111111-1111-4111-8111-111111111111',
 STAGING_SLUG:'chr-staging',
 STAGING_EMAIL:'test@invalid.example',
 STAGING_PASSWORD:'not-a-real-credential',
 STAGING_SEED_COUNT:'100000'
};
function attempt(overrides){
 return spawnSync(process.execPath,[loader],{
  cwd:root,env:{...process.env,...base,...overrides},encoding:'utf8',timeout:3500
 });
}
test('100k fixture seeder refuses the actual connected CHR project',()=>{
 const p=attempt({STAGING_URL:'https://dkisxdquvryoddpphgeg.supabase.co'});
 assert.equal(p.status,2);
 assert.match(p.stderr,/REFUSED/);
 assert.equal(p.stdout,'');
});
test('100k fixture seeder refuses a missing explicit staging confirmation',()=>{
 const p=attempt({
  STAGING_URL:'https://fake-staging-ref.supabase.co',
  ALLOW_CHR_STAGING_SEED:'NO'
 });
 assert.equal(p.status,2);
 assert.match(p.stderr,/REFUSED/);
});
test('100k fixture seeder rejects invalid fixture size before any network call',()=>{
 const p=attempt({
  STAGING_URL:'https://fake-staging-ref.supabase.co',
  STAGING_SEED_COUNT:'1000000'
 });
 assert.equal(p.status,2);
 assert.match(p.stderr,/REFUSED/);
});
