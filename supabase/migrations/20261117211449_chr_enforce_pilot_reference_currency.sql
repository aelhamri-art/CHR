-- CHR pilot invariant: one reference currency (EUR) until multi-currency pricing is implemented.
alter table public.stores add constraint stores_chr_eur_only check(currency='EUR');
