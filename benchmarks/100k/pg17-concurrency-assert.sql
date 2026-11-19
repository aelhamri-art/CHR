-- Post-run assertions, disposable CI instance only.
do $test$
declare n integer;v integer;
begin
 select count(*) into n from public.orders where store_id='c3000000-0000-4000-8000-000000000003';
 if n<>2 then raise exception 'Expected exactly two orders, got %',n;end if;
 select count(*) into n from public.order_requests r
 where r.store_id='c3000000-0000-4000-8000-000000000003';
 if n<>2 then raise exception 'Expected exactly two idempotency mappings, got %',n;end if;
 select count(*) into n from public.order_lines where store_id='c3000000-0000-4000-8000-000000000003';
 if n<>2 then raise exception 'Expected two captured SKU order lines, got %',n;end if;
 select sum(reserved) into v from public.inventory_levels
 where store_id='c3000000-0000-4000-8000-000000000003';
 if v<>2 then raise exception 'Expected two reserved units, got %',v;end if;
 select count(*) into n from public.inventory_levels
 where store_id='c3000000-0000-4000-8000-000000000003'
 and (on_hand<>1 or reserved<>1 or reserved>on_hand);
 if n<>0 then raise exception 'OVERSOLD or inconsistent inventory';end if;
 select count(*) into n from public.orders
 where store_id='c3000000-0000-4000-8000-000000000003'
   and (subtotal_minor<>10000 or shipping_minor<>1000 or tax_minor<>2200 or total_minor<>13200);
 if n<>0 then raise exception 'Transactional amount mismatch';end if;
end $test$;
select 'PASS: 32 simultaneous workers, two unique orders, stock never over-reserved' as result;
