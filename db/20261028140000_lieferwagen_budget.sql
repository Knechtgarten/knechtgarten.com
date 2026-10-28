-- Lieferwagen in der Offerte: dritte Rechenart "Budget" (fester Betrag in CHF statt Std oder km), Nutzerwunsch 2026-10-28.
alter table offerte drop constraint if exists offerte_lieferwagen_modus_check;
alter table offerte add constraint offerte_lieferwagen_modus_check check (lieferwagen_modus = any (array['zeit', 'distanz', 'budget']));
alter table offerte add column if not exists lieferwagen_budget numeric;
