-- Offerten-Blatt: Bezeichnung einer berechneten Zeile von Hand ändern (wie Menge/Preis/Einheit), Stefan 17.11.2026
alter table public.offerte_zeilen_korrektur add column if not exists bezeichnung_korrektur text;
select column_name from information_schema.columns where table_name = 'offerte_zeilen_korrektur' and column_name = 'bezeichnung_korrektur';
