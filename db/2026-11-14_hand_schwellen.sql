-- Neue Ansicht Tool A: ab wann eine Handänderung als «grosse Abweichung» (rot) gilt – Prozent ODER CHF (gleichwertig).
alter table public.lieferwagen_konfiguration
  add column if not exists hand_gross_proz numeric not null default 20,
  add column if not exists hand_gross_chf numeric not null default 500;
comment on column public.lieferwagen_konfiguration.hand_gross_proz is 'Handänderung rot ab dieser Abweichung des Zeilentotals in %';
comment on column public.lieferwagen_konfiguration.hand_gross_chf is 'Handänderung rot ab dieser Abweichung des Zeilentotals in CHF';
