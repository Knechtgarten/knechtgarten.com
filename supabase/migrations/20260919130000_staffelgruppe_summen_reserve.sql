-- Reserve % fuer den Summenmodus einer Staffelgruppe (siehe
-- 20260919120000_staffelgruppe_summenmodus.sql): wird auf die gebildete
-- Summe aufgeschlagen, BEVOR die passende Stufe gesucht wird - z.B. 15%
-- Verschnitt/Reserve auf die Gesamt-Watt-Summe der Leuchten, bevor das
-- passende Netzteil bestimmt wird. null/0 = keine Reserve (bisheriges
-- Verhalten unveraendert).
-- "if not exists" auch bei den beiden Spalten aus der vorigen Migration,
-- falls diese noch nicht gelaufen sein sollte.
alter table staffelgruppe add column if not exists summen_zusatzeinheit text null;
alter table staffelgruppe add column if not exists summen_scope text null check (summen_scope in ('offerte', 'arbeitsschritt'));
alter table staffelgruppe add column if not exists summen_reserve_prozent numeric null default 0;
