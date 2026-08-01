-- ============================================================================
-- Offertentool 2027 - Eingabefeld: optionaler Mindestwert (Zahl-Felder) fuer
-- eine visuelle Warnung in Tool A, wenn der Mitarbeiter einen unplausiblen
-- Wert eintraegt (z.B. Beckenkonstruktion sollte mindestens 10cm sein).
-- fixer_wert wird ab jetzt bei Zahl-Feldern zusaetzlich als optionaler
-- Vorschlagswert genutzt (vorbefuellt in Tool A, aber ueberschreibbar) -
-- bei Ja/Nein-Feldern bleibt es wie bisher der Pflicht-Fixwert.
-- ============================================================================

alter table eingabefeld add column mindestwert numeric null;
