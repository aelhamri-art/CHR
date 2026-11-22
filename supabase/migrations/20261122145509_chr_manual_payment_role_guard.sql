-- AXIUM OS CHR P0: explicit owner-controlled financial authority.
alter table public.chr_business_policies
 add column if not exists allow_manager_manual_payment boolean not null default false;

CREATE OR REPLACE FUNCTION public.confirm_manual_payment(p_store_id uuid, p_order_id uuid, p_method text, p_reference text, p_confirmation text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_order record; v_tx uuid;
begin
 if auth.uid() is null or not app_private.can_manage_store(p_store_id)
 then raise exception 'Access denied' using errcode='42501';end if;
 -- An ordinary manager cannot self-certify an incoming payment unless
 -- the owner has explicitly enabled that capability for this store.
 if not (
  exists(select 1 from public.stores s
         where s.id=p_store_id and s.owner_user_id=auth.uid())
  or exists(select 1 from public.store_members m
    where m.store_id=p_store_id and m.user_id=auth.uid()
      and m.status='active' and m.role='admin')
  or (
   coalesce((select p.allow_manager_manual_payment
      from public.chr_business_policies p where p.store_id=p_store_id),false)
   and exists(select 1 from public.store_members m
    where m.store_id=p_store_id and m.user_id=auth.uid()
      and m.status='active' and m.role='manager')
  )
 ) then
  raise exception 'Manual payment confirmation requires financial permission'
   using errcode='42501';
 end if;
 if p_confirmation<>'PAIEMENT RECU' or p_method not in ('bank_transfer','cash','cheque')
  or length(trim(coalesce(p_reference,'')))<5 then
  raise exception 'Human confirmation and bank/cash reference required' using errcode='22023';end if;
 select * into v_order from public.orders where store_id=p_store_id and id=p_order_id for update;
 if not found or v_order.status<>'open' or v_order.payment_status<>'pending'
 then raise exception 'Order is not waiting for payment' using errcode='23514';end if;
 insert into public.payment_transactions(store_id,order_id,provider,provider_event_id,provider_reference,kind,status,amount_minor,currency)
 values(p_store_id,p_order_id,'manual',p_reference,p_reference,'capture','succeeded',v_order.total_minor,v_order.currency)
 returning id into v_tx;
 update public.orders set payment_status='paid',updated_at=now() where id=p_order_id;
 insert into public.audit_events(store_id,actor_id,actor_type,entity_type,entity_id,action,after_state)
 values(p_store_id,auth.uid(),'human','orders',p_order_id,'manual_payment_confirmed',
 jsonb_build_object('method',p_method,'reference',p_reference,'amount_minor',v_order.total_minor,'transaction_id',v_tx));
 return jsonb_build_object('status','paid','transaction_id',v_tx);
end $function$;

-- Ensure manual payment RPC is never accidentally granted to anonymous.
revoke all on function public.confirm_manual_payment(uuid,uuid,text,text,text)
 from public,anon,authenticated;
grant execute on function public.confirm_manual_payment(uuid,uuid,text,text,text)
 to authenticated;
