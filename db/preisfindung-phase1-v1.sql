-- ============================================================================
-- Offertentool 2027 - Preisfindung Phase 1: Datenmodell fuer Staffelmengen
-- (z.B. Betonpumpe-Staffelpreise) und PLZ-Zonen (z.B. Kies-/Beton-Transport).
-- Reine Datenpflege in dieser Phase - noch keine Verknuepfung mit Tool B
-- (Ressourcenzeile) oder der Berechnung in Tool A (folgt in Phase 2).
-- ============================================================================

-- Kunde-PLZ: strukturiertes Feld (bisher nur Freitext-Adresse), noetig fuer
-- automatischen PLZ-Abgleich (Zonen, spaeter Lieferwagenfahrzeit).
alter table kunde add column plz text null;

-- ----------------------------------------------------------------------------
-- Staffelmengen: mehrere bestehende Artikel zu einer Menge-Staffel gruppieren
-- (z.B. "Betonpumpe": 0-5m3 -> Artikel A, 5-10m3 -> Artikel B, ...).
-- ----------------------------------------------------------------------------
create table staffelgruppe (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  erstellt_am timestamptz not null default now()
);
create table staffelstufe (
  id uuid primary key default gen_random_uuid(),
  staffelgruppe_id uuid not null references staffelgruppe(id) on delete cascade,
  menge_von numeric not null,
  menge_bis numeric null, -- null = keine Obergrenze (oberste Stufe)
  artikel_id uuid not null references artikel(id) on delete restrict,
  reihenfolge int not null default 0
);

-- ----------------------------------------------------------------------------
-- PLZ-Zonen: z.B. eigene Zonengruppen "Kies-Transport"/"Beton-Transport",
-- je 1..N Zonen mit eigenem Artikel + Liste zugehoeriger PLZ.
-- ----------------------------------------------------------------------------
create table zonengruppe (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  erstellt_am timestamptz not null default now()
);
create table zone (
  id uuid primary key default gen_random_uuid(),
  zonengruppe_id uuid not null references zonengruppe(id) on delete cascade,
  nummer int not null,
  artikel_id uuid not null references artikel(id) on delete restrict,
  reihenfolge int not null default 0
);
create table zone_plz (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid not null references zone(id) on delete cascade,
  plz text not null
);
create index zone_plz_plz_idx on zone_plz(plz);

-- ----------------------------------------------------------------------------
-- RLS: gleiches Muster wie andere Katalog-/Definitionstabellen - lesen fuer
-- jeden eingeloggten Benutzer (Tool A braucht das spaeter fuer die
-- Berechnung), schreiben nur Admin (Pflege lebt in Einstellungen).
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['staffelgruppe','staffelstufe','zonengruppe','zone','zone_plz'] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_lesen on %I for select using (ist_eingeloggter_benutzer());', t, t);
    execute format('create policy %I_admin_schreibt on %I for all using (ist_admin()) with check (ist_admin());', t, t);
  end loop;
end $$;
