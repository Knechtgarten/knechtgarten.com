-- ============================================================================
-- Offertentool 2027 - Staffelgruppe: optionaler Referenzwert statt Menge-Formel
-- pro Ressourcenzeile. Bisher musste jede Ressourcenzeile, die eine
-- Staffelgruppe (z.B. "Betonpumpe") verwendet, ihre eigene Menge-Formel neu
-- aufbauen, um zu bestimmen, welche Staffelstufe zutrifft. Jetzt kann die
-- Staffelgruppe selbst EINEN Eingabefeld- oder Wert-Verweis hinterlegen
-- (z.B. "Beckenvolumen") - ist das gesetzt, wird dessen Wert fuer die
-- Stufen-Auswahl verwendet statt der Ressourcenzeilen-eigenen Formel.
--
-- staffel_referenz an eingabefeld/term markiert, welche Eingabefelder/Werte
-- ueberhaupt zur Auswahl stehen sollen (sonst waere die Auswahlliste voll mit
-- Werten, die als Staffel-Referenz keinen Sinn ergeben, z.B. "Fundamentdicke").
-- ============================================================================

alter table eingabefeld add column staffel_referenz boolean not null default false;
alter table term add column staffel_referenz boolean not null default false;

alter table staffelgruppe add column referenz_eingabefeld_id uuid null references eingabefeld(id) on delete set null;
alter table staffelgruppe add column referenz_term_id uuid null references term(id) on delete set null;
