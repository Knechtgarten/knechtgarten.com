-- ============================================================================
-- Offertentool 2027 - Alte, nie verwendete Teilflaechenlogik entfernen
--
-- Aus der allerersten Basis-Migration (db/schema-v1-pilotkette.sql):
-- ressourcenzeile.geltungsbereich (teilflaeche/bauteil/offerte) und
-- ressourcenzeile.teilflaechenlogik (pro_teilflaeche/einmal_bauteil/
-- gepoolt_runden) sollten mal regeln, wie eine Ressourcenzeile ueber mehrere
-- Teilflaechen hinweg zusammenspielt ("3-Stufen-Regel"). Wurde nie in Tool A
-- oder Tool B verdrahtet (kein Code liest/schreibt diese Spalten) - der
-- Nutzer moechte diese Logik komplett neu aufbauen, statt auf der alten,
-- nie genutzten Struktur aufzusetzen.
-- ============================================================================

alter table ressourcenzeile drop column if exists geltungsbereich;
alter table ressourcenzeile drop column if exists teilflaechenlogik;
