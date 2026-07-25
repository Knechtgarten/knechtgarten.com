-- ============================================================================
-- Offertentool 2027 - Logistik-Sammelpositionen
--
-- Identisches Muster wie Maschinen-Sammelpositionen (siehe
-- db/maschinen-sammelposition-v1.sql): Logistikaufwand wird in der
-- Kostentabelle (Tool A) grundsaetzlich ueber die ganze Offerte hinweg pro
-- Artikel summiert. Admins koennen hier zusaetzlich benannte
-- "Sammelpositionen" definieren (z.B. "Entsorgung" fuer mehrere
-- Entsorgungs-Artikel), damit bestimmte Artikel-Gruppen als eigene Zeile
-- ausgewiesen werden statt einzeln aufgefuehrt zu sein. Nicht zugeordnete
-- Logistik-Artikel erscheinen weiterhin einzeln (siehe recalc() in
-- tool-a-live-v1.html).
--
-- Gilt bewusst nur fuer Offerte-Typ "Formel" (siehe Formel-Only-Guards in
-- tool-a-live-v1.html).
--
-- Muster wie staffelstufe/zone/maschinen_sammelposition (ein Artikel pro
-- Zeile statt einer Array-Spalte).
-- ============================================================================

create table logistik_sammelposition (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  reihenfolge integer not null default 0
);
alter table logistik_sammelposition enable row level security;
create policy logistik_sammelposition_lesen on logistik_sammelposition for select using (ist_eingeloggter_benutzer());
create policy logistik_sammelposition_admin_schreibt on logistik_sammelposition for all using (ist_admin()) with check (ist_admin());

create table logistik_sammelposition_artikel (
  id uuid primary key default gen_random_uuid(),
  sammelposition_id uuid not null references logistik_sammelposition(id) on delete cascade,
  artikel_id uuid not null references artikel(id) on delete cascade,
  unique (sammelposition_id, artikel_id)
);
alter table logistik_sammelposition_artikel enable row level security;
create policy logistik_sammelposition_artikel_lesen on logistik_sammelposition_artikel for select using (ist_eingeloggter_benutzer());
create policy logistik_sammelposition_artikel_admin_schreibt on logistik_sammelposition_artikel for all using (ist_admin()) with check (ist_admin());
