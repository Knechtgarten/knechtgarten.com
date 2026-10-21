-- ============================================================================
-- Pflege-Tool: Kundenkarte (Google Maps)
--   app_einstellung: kleine Schluessel/Wert-Tabelle, z. B. der Browser-Schluessel
--   fuer Google Maps (auf knechtgarten.com + Maps JavaScript API beschraenkt).
--   Lesen nur eingeloggte Benutzer, aendern nur Admins.
--   Koordinaten pro Kunde (Hauptadresse) und Objekt; geo_adresse = Adresse, fuer die
--   die Koordinaten berechnet wurden (aendert sich die Adresse, wird neu berechnet).
-- ============================================================================
create table app_einstellung (
  schluessel text primary key,
  wert text,
  aktualisiert_am timestamptz not null default now()
);
alter table app_einstellung enable row level security;
create policy app_einstellung_lesen on app_einstellung for select using (ist_eingeloggter_benutzer());
create policy app_einstellung_admin on app_einstellung for all
  using (exists (select 1 from benutzer b where b.id = auth.uid() and b.rolle = 'admin' and b.aktiv))
  with check (exists (select 1 from benutzer b where b.id = auth.uid() and b.rolle = 'admin' and b.aktiv));

alter table pflege_kunde add column lat double precision, add column lon double precision,
  add column geo_adresse text, add column geo_ok boolean;
alter table pflege_objekt add column lat double precision, add column lon double precision,
  add column geo_adresse text, add column geo_ok boolean;
