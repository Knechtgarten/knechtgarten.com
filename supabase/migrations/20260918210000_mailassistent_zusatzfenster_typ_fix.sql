-- ============================================================================
-- Mail-Assistent: Zusatzfenster-Typ "tabelle_fix" (feste Zeilen).
--
-- Bisher war "Positionen" ein optionaler Zusatz innerhalb des Typs
-- "tabelle" - das fuehrte laufend zu Verwechslungen (wachsende Liste vs.
-- feste Auswahl). Jetzt zwei klar getrennte Typen:
--   'tabelle'      - nur Spalten, waechst in Gmail frei (keine Positionen).
--   'tabelle_fix'  - feste Positionen (z.B. "Lampe 1"-5) mit Anzahl-Feld
--                    davor, optional zusaetzliche Spalten.
-- ============================================================================

alter table mailassistent_zusatzfenster drop constraint if exists mailassistent_zusatzfenster_typ_check;
alter table mailassistent_zusatzfenster add constraint mailassistent_zusatzfenster_typ_check
  check (typ in ('tabelle','tabelle_fix','kalender'));
