-- Einsatzplaner: Reservetage hinter einem Auftrag (schraffiert, wandern mit, halbe Tage möglich)
alter table public.planer_einsatz add column if not exists reserve_tage numeric not null default 0 check (reserve_tage >= 0 and reserve_tage <= 60);
