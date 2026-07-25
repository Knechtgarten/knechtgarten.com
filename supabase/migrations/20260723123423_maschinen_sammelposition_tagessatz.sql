-- ============================================================================
-- Offertentool 2027 - Maschinen-Sammelpositionen fuer Offerten nach
-- Stundenberechnung (Tagessatz/"Allgemein").
--
-- Identisches Muster wie db/maschinen-sammelposition-v1.sql (dort fuer
-- Offerten nach Mengenberechnung/Formel) - eigene Tabellen statt Wieder-
-- verwendung, damit Formel- und Tagessatz-Sammelpositionen unabhaengig
-- voneinander gepflegt werden koennen (z.B. unterschiedliche Gruppierungen
-- je Offerte-Typ).
-- ============================================================================

create table maschinen_sammelposition_tagessatz (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  reihenfolge integer not null default 0
);
alter table maschinen_sammelposition_tagessatz enable row level security;
create policy maschinen_sammelposition_tagessatz_lesen on maschinen_sammelposition_tagessatz for select using (ist_eingeloggter_benutzer());
create policy maschinen_sammelposition_tagessatz_admin_schreibt on maschinen_sammelposition_tagessatz for all using (ist_admin()) with check (ist_admin());

create table maschinen_sammelposition_tagessatz_artikel (
  id uuid primary key default gen_random_uuid(),
  sammelposition_id uuid not null references maschinen_sammelposition_tagessatz(id) on delete cascade,
  artikel_id uuid not null references artikel(id) on delete cascade,
  unique (sammelposition_id, artikel_id)
);
alter table maschinen_sammelposition_tagessatz_artikel enable row level security;
create policy maschinen_sammelposition_tagessatz_artikel_lesen on maschinen_sammelposition_tagessatz_artikel for select using (ist_eingeloggter_benutzer());
create policy maschinen_sammelposition_tagessatz_artikel_admin_schreibt on maschinen_sammelposition_tagessatz_artikel for all using (ist_admin()) with check (ist_admin());
