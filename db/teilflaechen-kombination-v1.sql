-- ============================================================================
-- Offertentool 2027 - Teilflaechen-Kombination (Grundlage)
--
-- Ersetzt das bisher inaktive "TF"-Haekchen in Tool B durch ein echtes Feld.
-- Markiert Ressourcenzeilen, deren Menge vor der Preisberechnung ueber alle
-- Teilflaechen einer Offerte hinweg zusammengezaehlt werden soll (z.B. Mulden-
-- Kapazitaet, Staffelstufen, Pauschalen bei Kies-/Beton-Transport) statt wie
-- bisher pro Teilflaeche unabhaengig gerechnet zu werden.
--
-- Vorerst nur bei Logistik-Zeilen in Tool B aktivierbar (siehe
-- istTeilflaechenKombinationFaehigeKategorie() in tool-b-live-v1.html) -
-- Material folgt evtl. spaeter. Die eigentliche Berechnung in Tool A
-- (recalc()) ist noch NICHT Teil dieser Migration - das Feld wird hier nur
-- gespeichert, aber noch nicht ausgewertet.
-- ============================================================================

alter table ressourcenzeile add column teilflaechen_kombination boolean not null default false;
