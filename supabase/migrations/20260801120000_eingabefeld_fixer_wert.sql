-- ============================================================================
-- Offertentool 2027 - "Fixer Wert" fuer Eingabefeld-Typ "Ja/Nein". Der Admin
-- traegt den festen Wert (z.B. 18 fuer Mauerdicke Coffra in cm) direkt beim
-- Eingabefeld ein - der Mitarbeiter in Tool A sieht dafuer nur ein Haekchen
-- und kann den Wert selbst nicht veraendern. Aktiviert der Mitarbeiter das
-- Haekchen, wird fixer_wert als Wert des Eingabefelds in die Formel
-- uebernommen, sonst 0.
-- ============================================================================

alter table eingabefeld add column fixer_wert numeric null;
