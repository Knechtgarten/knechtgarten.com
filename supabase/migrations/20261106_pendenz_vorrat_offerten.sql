-- Zugesagte Offerte → Arbeitsvorrat: welche Offerten gehören dazu, plus eigene Zusatzzeit
alter table pendenz add column if not exists vorrat_offerte_ids uuid[];       -- Offerten aus dem Offertentool
alter table pendenz add column if not exists vorrat_easybill text[];          -- direkt in Easybill geschriebene Offerten (Nummer)
alter table pendenz add column if not exists vorrat_zusatz_tage numeric;      -- zusätzliche Zeit (eigene Eingabe)
alter table pendenz add column if not exists vorrat_zusatz_text text;
