-- ============================================================================
-- Offertentool 2027 - Beschreibungs-Blocktext (vor dem Total in der Kostentabelle)
--
-- Fortlaufender Text ohne Titel/Absaetze, automatisch aus den Beschreibungen
-- der tatsaechlich verwendeten Teilschritte (Pool/Formel-Offerten) bzw.
-- Arbeitsschritte + Eigene Positionen (Allgemein/Tagessatz-Offerten)
-- zusammengesetzt. Frei manuell nachbearbeitbar - sobald der Nutzer den Text
-- manuell anpasst, darf die Automatik ihn nicht mehr ueberschreiben.
-- ============================================================================

alter table offerte add column beschreibung_block text null;
alter table offerte add column beschreibung_manuell boolean not null default false;
