-- ============================================================================
-- Offertentool 2027 - Maschinen-Sammelpositionen
--
-- Maschinenaufwand wird in der Kostentabelle (Tool A) grundsaetzlich ueber die
-- ganze Offerte hinweg zu einer Budget-Zeile zusammengezaehlt. Admins koennen
-- hier zusaetzlich benannte "Sammelpositionen" definieren (z.B. "Baumaschinen"
-- fuer Bagger S/M/L), damit bestimmte Artikel-Gruppen als eigene Zeile
-- ausgewiesen werden statt im generischen Topf zu verschwinden. Nicht
-- zugeordnete Maschinen-Artikel landen weiterhin gemeinsam in der generischen
-- "Maschinenaufwand"-Zeile (siehe recalc() in tool-a-live-v1.html).
--
-- Gilt bewusst nur fuer Offerte-Typ "Formel" (siehe Formel-Only-Guards in
-- tool-a-live-v1.html).
--
-- Muster wie staffelstufe/zone (ein Artikel pro Zeile statt einer Array-
-- Spalte, gleiche Konvention wie an anderen Stellen im Projekt).
-- ============================================================================

create table maschinen_sammelposition (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  reihenfolge integer not null default 0
);
alter table maschinen_sammelposition enable row level security;
create policy maschinen_sammelposition_lesen on maschinen_sammelposition for select using (ist_eingeloggter_benutzer());
create policy maschinen_sammelposition_admin_schreibt on maschinen_sammelposition for all using (ist_admin()) with check (ist_admin());

create table maschinen_sammelposition_artikel (
  id uuid primary key default gen_random_uuid(),
  sammelposition_id uuid not null references maschinen_sammelposition(id) on delete cascade,
  artikel_id uuid not null references artikel(id) on delete cascade,
  unique (sammelposition_id, artikel_id)
);
alter table maschinen_sammelposition_artikel enable row level security;
create policy maschinen_sammelposition_artikel_lesen on maschinen_sammelposition_artikel for select using (ist_eingeloggter_benutzer());
create policy maschinen_sammelposition_artikel_admin_schreibt on maschinen_sammelposition_artikel for all using (ist_admin()) with check (ist_admin());
