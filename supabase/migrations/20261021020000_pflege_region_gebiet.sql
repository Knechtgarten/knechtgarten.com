-- Pflege-Tool: berechnetes Gebiet pro Region fuer die Kundenkarte
-- (Liste von Pfaden [[lat,lng],...]; berechnet aus PLZ-Ortschaften + Kundenpunkten, geglaettet)
alter table pflege_region add column if not exists gebiet jsonb;
