-- ============================================================================
-- Ressourcenzeile-Mengen-Korrektur (Tagesrechner, siehe
-- 20260825110000_ressourcenzeile_menge_korrektur.sql): zusaetzlich ein
-- klarer "fuer diese Offerte deaktiviert"-Schalter statt sich auf
-- "Gesamtmenge auf 0 setzen" verlassen zu muessen - gleiches Muster wie die
-- bestehende Korrektur der Kostentabellen-Zeilen (offerte_zeilen_korrektur.
-- geloescht).
-- ============================================================================

alter table offerte_ressourcenzeile_korrektur alter column menge drop not null;
alter table offerte_ressourcenzeile_korrektur add column geloescht boolean not null default false;
