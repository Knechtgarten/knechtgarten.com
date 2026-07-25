-- ============================================================================
-- Offertentool 2027 - Mindestbetrag (CHF) war am falschen Ort/Konzept - wird
-- zur Mindestmenge (m3, Mindestverrechnungsmenge pro Fahrt) am Kieswerk.
-- Bleibt bewusst am Kieswerk (Einstellungen), nicht an der Ressourcenzeile
-- (Tool B): die Mindestabnahmemenge ist eine feste Eigenschaft der Logistik
-- des jeweiligen Kieswerks (LKW-Kapazitaet), unabhaengig davon, in welchem
-- Teilschritt/Auswahlfeld das Kieswerk verwendet wird.
--
-- Robust gegen beide moeglichen Ausgangslagen: falls die Spalte "mindestbetrag"
-- noch existiert (Migration 20260724220000 zum Loeschen noch nicht gelaufen),
-- wird sie umbenannt statt geloescht+neu angelegt. Falls sie schon geloescht
-- wurde, wird "mindestmenge" stattdessen frisch angelegt. In beiden Faellen
-- ist "mindestmenge" danach vorhanden - die Migration 20260724220000 muss
-- deshalb nicht mehr separat ausgefuehrt werden, falls das noch aussteht.
-- ============================================================================

do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'kieswerk_kies' and column_name = 'mindestbetrag') then
    alter table kieswerk_kies rename column mindestbetrag to mindestmenge;
  elsif not exists (select 1 from information_schema.columns where table_name = 'kieswerk_kies' and column_name = 'mindestmenge') then
    alter table kieswerk_kies add column mindestmenge numeric;
  end if;

  if exists (select 1 from information_schema.columns where table_name = 'kieswerk_beton' and column_name = 'mindestbetrag') then
    alter table kieswerk_beton rename column mindestbetrag to mindestmenge;
  elsif not exists (select 1 from information_schema.columns where table_name = 'kieswerk_beton' and column_name = 'mindestmenge') then
    alter table kieswerk_beton add column mindestmenge numeric;
  end if;
end $$;
