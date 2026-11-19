-- CHR / security regression: single-adjustment replay and conflicting idempotency key.
-- Uses pre-existing owner only to simulate authenticated JWT. Everything is rolled back.
begin;
do $fixture$
declare s uuid;u uuid;p uuid;v uuid;l uuid;
begin
 select id,owner_user_id into s,u from public.stores where slug='chr' limit 1;
 if s is null or u is null then raise exception 'Missing store/owner';end if;
 insert into public.products(store_id,title,handle,status) values
 (s,'Rollback inventory fixture','inventory-fixture-'||substr(gen_random_uuid()::text,1,8),'draft') returning id into p;
 insert into public.product_variants(store_id,product_id,title,sku)
 values(s,p,'Fixture','INV-'||substr(gen_random_uuid()::text,1,8)) returning id into v;
 insert into public.locations(store_id,name) values(s,'Rollback inventory location') returning id into l;
 perform set_config('chr.test.stock',jsonb_build_object('s',s,'v',v,'l',l,'k',gen_random_uuid())::text,true);
 perform set_config('request.jwt.claim.sub',u::text,true);
end $fixture$;
set local role authenticated;
do $verify$
declare d jsonb:=current_setting('chr.test.stock')::jsonb; r jsonb; blocked boolean:=false; n integer;
begin
 r:=public.adjust_inventory((d->>'s')::uuid,(d->>'v')::uuid,(d->>'l')::uuid,5,'receipt',(d->>'k')::uuid);
 if r->>'status'<>'applied' then raise exception 'First adjustment was not applied';end if;
 r:=public.adjust_inventory((d->>'s')::uuid,(d->>'v')::uuid,(d->>'l')::uuid,5,'receipt',(d->>'k')::uuid);
 if r->>'status'<>'already_applied' then raise exception 'Replay was not idempotent';end if;
 begin
  perform public.adjust_inventory((d->>'s')::uuid,(d->>'v')::uuid,(d->>'l')::uuid,7,'receipt',(d->>'k')::uuid);
 exception when check_violation then blocked:=true;
 end;
 if not blocked then raise exception 'CRITICAL: conflicting adjustment replay accepted';end if;
 select on_hand into n from public.inventory_levels
 where store_id=(d->>'s')::uuid and variant_id=(d->>'v')::uuid and location_id=(d->>'l')::uuid;
 if n<>5 then raise exception 'Double adjustment or corrupted on_hand';end if;
 select count(*) into n from public.inventory_movements
 where store_id=(d->>'s')::uuid and idempotency_key=(d->>'k')::uuid;
 if n<>1 then raise exception 'Duplicate movement records';end if;
end $verify$;
rollback;
select 'PASS: first apply, identical replay, conflicting replay rejected, one movement' as result;