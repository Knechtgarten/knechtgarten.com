-- ============================================================================
-- Offertentool 2027 - Eingabefeld: Beschriftung/Erklaerung fuer Tool A +
-- Ausblenden-Option.
--
-- beschriftung: optionale eigene Beschriftung fuer das Eingabefeld im
-- Konfigurator (Tool A) - kann kuerzer oder ausfuehrlicher sein als "name"
-- (name bleibt die interne Bezeichnung in Listen/Formeln). Leer = "name"
-- wird weiterhin als Beschriftung verwendet.
--
-- erklaerung: Tooltip-Text, der im Konfigurator beim Ueberfahren mit der
-- Maus erscheint.
--
-- ausgeblendet: blendet das Eingabefeld im Konfigurator (Tool A) komplett
-- aus - der Wert wird aber weiterhin in Formeln/Berechnungen verwendet
-- (als fixer Wert, siehe eingabefeld.fixer_wert). Praktisch fuer Werte,
-- die praktisch immer gleich sind und den Mitarbeiter nicht bei jeder
-- Offerte erneut beschaeftigen sollen.
-- ============================================================================

alter table eingabefeld add column if not exists beschriftung text null;
alter table eingabefeld add column if not exists erklaerung text null;
alter table eingabefeld add column if not exists ausgeblendet boolean not null default false;
