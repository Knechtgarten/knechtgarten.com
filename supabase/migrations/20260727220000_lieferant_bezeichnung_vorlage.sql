-- ============================================================================
-- Offertentool 2027 - Bezeichnungs-Vorlage pro Lieferant fuer die
-- Schnellerfassung (Tool C): merkt sich die zuletzt verwendete Reihenfolge
-- der Bausteine (feste Textstuecke + Felder wie Marke/Modell/Farbe/Masse/
-- Volumen), damit sie beim naechsten Mal fuer denselben Lieferanten wieder
-- vorausgefuellt ist, statt jedes Mal neu zusammengeklickt werden zu muessen.
-- ============================================================================

alter table lieferant_datenabgleich add column bezeichnung_vorlage jsonb;
