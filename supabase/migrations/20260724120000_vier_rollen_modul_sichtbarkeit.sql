-- ============================================================================
-- Offertentool 2027 - Vierstufiges Rollenmodell + Modul-Sichtbarkeit.
--
-- Bisher gab es nur admin/mitarbeiter. Neu: admin / buero_team /
-- mitarbeitende / service_team - alle vier haben im Offertentool selbst
-- weiterhin identische Rechte wie bisher "mitarbeiter" (nur admin ist
-- weiterhin die einzige privilegierte Stufe fuer Schreibzugriffe auf
-- Formel-Bibliothek/Artikelstamm/Benutzerverwaltung). Der einzige neue
-- Unterschied zwischen den drei Nicht-Admin-Rollen ist, welche Module auf
-- der Tools-Startseite (knechtgarten.com) sichtbar sind - gesteuert ueber
-- die neue Tabelle modul_sichtbarkeit.
-- ============================================================================

alter table benutzer drop constraint if exists benutzer_rolle_check;
alter table benutzer add constraint benutzer_rolle_check
  check (rolle in ('admin','buero_team','mitarbeitende','service_team'));

update benutzer set rolle = 'buero_team' where rolle = 'mitarbeiter';

-- ----------------------------------------------------------------------------
-- Modul-Sichtbarkeit: pro (noch kommendem) Modul ein Häkchen je Rolle, ob es
-- auf der Tools-Startseite fuer diese Rolle erscheint. Das Offertentool
-- selbst ist nicht Teil dieser Tabelle - es ist fuer jeden eingeloggten,
-- zugewiesenen Benutzer immer sichtbar (Basis-Tool). Admin sieht in der App
-- ohnehin immer alles, unabhaengig von dieser Tabelle.
-- ----------------------------------------------------------------------------
create table modul_sichtbarkeit (
  modul_key text primary key,
  name text not null,
  fuer_buero_team boolean not null default true,
  fuer_mitarbeitende boolean not null default true,
  fuer_service_team boolean not null default true
);

insert into modul_sichtbarkeit (modul_key, name) values
  ('kundenanfragen', 'Kundenanfragen'),
  ('berechnungstool', 'Berechnungstool'),
  ('arbeitssicherheit', 'Arbeitssicherheit'),
  ('bestellungen', 'Bestellungen'),
  ('pflanzplanung', 'Pflanzplanung');

alter table modul_sichtbarkeit enable row level security;
create policy modul_sichtbarkeit_lesen on modul_sichtbarkeit
  for select using (ist_eingeloggter_benutzer());
create policy modul_sichtbarkeit_admin_schreibt on modul_sichtbarkeit
  for all using (ist_admin()) with check (ist_admin());
