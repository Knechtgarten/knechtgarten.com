-- ============================================================================
-- Offertentool 2027 - Lieferanten-Erfassung wandert zu Einstellungen,
-- deshalb zurueck auf Admin-only Schreibrecht (Korrektur zur vorherigen
-- Migration mitarbeiter-vollzugriff-plus-einstellungen-v1.sql, die lieferant
-- versehentlich mit auf "voller Zugriff" gesetzt hatte). Artikel und
-- Artikelgruppe bleiben unveraendert fuer Mitarbeiter voll schreibbar - nur
-- die Lieferant-Stammzeile selbst (Anlegen/Loeschen/Umbenennen) ist wieder
-- Admin-only. Lesen bleibt fuer jeden eingeloggten Benutzer offen (bestehende
-- lieferant_lesen-Policy, unveraendert), noetig fuer die Lieferant-Auswahl
-- beim Artikel-Anlegen.
-- ============================================================================
drop policy if exists lieferant_voller_zugriff on lieferant;
create policy lieferant_admin_schreibt on lieferant for all using (ist_admin()) with check (ist_admin());
