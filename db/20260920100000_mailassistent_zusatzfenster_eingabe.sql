-- ============================================================================
-- Mail-Assistent: Zusatzfenster-Typ "eingabe" (Eingabe-Popup).
--
-- Bisherige Typen (tabelle/tabelle_fix/kalender) haben genau EINEN
-- gemeinsamen Platzhalter fuer das ganze Zusatzfenster. Der neue Typ
-- "eingabe" ist ein kleines Popup mit frei waehlbaren Textfeldern (z.B.
-- "Objekt") - jedes Feld bekommt SEINEN EIGENEN Platzhalter, weil die Werte
-- unabhaengig voneinander an mehreren Stellen eingesetzt werden sollen
-- (z.B. dasselbe "Objekt" sowohl im Betreff als auch im Mailtext).
--
-- Die Felder werden ueber die schon vorhandene Tabelle
-- mailassistent_zusatzfenster_spalte verwaltet (typ='text'), damit die
-- Verwaltung (beliebig viele Felder hinzufuegen/entfernen) wiederverwendet
-- werden kann statt eine eigene Tabelle zu brauchen.
-- ============================================================================

alter table mailassistent_zusatzfenster drop constraint if exists mailassistent_zusatzfenster_typ_check;
alter table mailassistent_zusatzfenster add constraint mailassistent_zusatzfenster_typ_check
  check (typ in ('tabelle','tabelle_fix','kalender','eingabe'));

alter table mailassistent_zusatzfenster_spalte drop constraint if exists mailassistent_zusatzfenster_spalte_typ_check;
alter table mailassistent_zusatzfenster_spalte add constraint mailassistent_zusatzfenster_spalte_typ_check
  check (typ in ('dropdown','zahl','text'));

alter table mailassistent_zusatzfenster_spalte add column if not exists platzhalter text unique;
