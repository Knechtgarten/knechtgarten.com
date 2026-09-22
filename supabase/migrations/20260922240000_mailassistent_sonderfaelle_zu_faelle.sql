-- ============================================================================
-- Mail-Assistent: Sonderfälle werden aufgelöst und wandern nach Fälle - für
-- Stefan sind "Sonderfall" und "Fall" dasselbe Konzept, eine eigene Rubrik
-- daneben ist ueberfluessig. Inhalt wird per SQL aus der Live-Tabelle
-- mailassistent_sonderfall kopiert (nicht abgetippt), damit nichts verloren
-- geht. Die Rubrik "Sonderfälle" wird danach im Tool entfernt (siehe
-- separater Code-Commit) - die Tabelle mailassistent_sonderfall selbst
-- bleibt unangetastet stehen (kein Datenverlust, nur nicht mehr verwendet).
-- ============================================================================

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Probleme mit Pflanzen (Diagnose)',
  'Stichwörter: ' || coalesce(stichwoerter, '') || E'\n\n' || coalesce(verhalten, ''),
  (select coalesce(max(reihenfolge), -1) + 1 from mailassistent_faelle_abschnitt)
from mailassistent_sonderfall
where titel = 'Probleme mit Pflanzen'
  and not exists (select 1 from mailassistent_faelle_abschnitt where titel = 'Probleme mit Pflanzen (Diagnose)');

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Auffangfall (wenn nichts anderes zutrifft)',
  coalesce(verhalten, ''),
  (select coalesce(max(reihenfolge), -1) + 1 from mailassistent_faelle_abschnitt)
from mailassistent_sonderfall
where titel = 'Auffangfall - nichts anderes trifft zu'
  and not exists (select 1 from mailassistent_faelle_abschnitt where titel = 'Auffangfall (wenn nichts anderes zutrifft)');
