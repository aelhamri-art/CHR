-- Run with psql -v order_key=UUID -v variant_id=UUID on independent connections.
set role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',false);
select public.create_order(
 'c3000000-0000-4000-8000-000000000003'::uuid,
 'f1000000-0000-4000-8000-000000000001'::uuid,
 'f2000000-0000-4000-8000-000000000001'::uuid,
 'f3000000-0000-4000-8000-000000000001'::uuid,
 'ZZ','00000',
 jsonb_build_array(jsonb_build_object('variant_id',:'variant_id'::uuid,'quantity',1)),
 :'order_key'::uuid
);
