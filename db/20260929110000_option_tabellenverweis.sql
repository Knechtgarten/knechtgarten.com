-- ============================================================================
-- Tabellenverweis bei Optionen (z.B. Belag): Die Menge (m²) der Option kommt
-- aus Zeilen von Eingabe-Tabellen, die der Mitarbeiter in Tool A bei der
-- Option anhakt - statt Menge von Hand zu tippen oder ein Dropdown in der Tabelle.
--
-- auswahloption.tabellenverweis : [{"eingabefeld_id": "...", "spalte_id": "..."}, ...]
--     welche Tabellen (und welche Spalte davon) zaehlen; null = kein Verweis
-- offerte_tabelle_zeile.option_id : zu welcher Option diese Zeile gehoert
--     (hoechstens eine - eine Flaeche wird nie doppelt gerechnet)
-- ============================================================================
alter table auswahloption add column if not exists tabellenverweis jsonb null;
alter table offerte_tabelle_zeile add column if not exists option_id uuid null references auswahloption(id) on delete set null;
