-- Bauprogramm (Einsatzplaner, Seite bauprogramm-live-v1.html): ein Programm pro Kunde/Baustelle, Blöcke in Reihenfolge.
-- Ein Block kennt seine Teile (teile = Schlüssel der Quellen):
--   'eb:<easybill_id>'                 = ganzes Easybill-Angebot (Stunden Vorarbeiter + Gartenarbeiter)
--   'ts:<offerte_id>:<teilschritt_id>' = Teilschritt einer Offerte aus dem Offertentool (Tage)
-- Tage = Summe der Teile (Stunden ÷ (Team × 8.5 h), aufgerundet) + extra (von Hand). Termine rechnet die Seite.

create table if not exists bauprogramm (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references kunde(id) on delete cascade,
  titel text,
  start date not null default current_date,
  erstellt_von uuid default auth.uid() references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create unique index if not exists bauprogramm_kunde on bauprogramm (kunde_id);

create table if not exists bauprogramm_block (
  id uuid primary key,
  programm_id uuid not null references bauprogramm(id) on delete cascade,
  sortierung integer not null default 0,
  name text not null,
  farbe text not null default 'grau',        -- Familie aus KG.palette
  teile jsonb not null default '[]'::jsonb,
  extra integer not null default 0,
  team integer not null default 2,
  fix date,
  mat text,                                   -- null = aus den Teilen
  sub text,
  ursprung_id uuid references bauprogramm_block(id) on delete set null
);
create index if not exists bauprogramm_block_programm on bauprogramm_block (programm_id, sortierung);

alter table bauprogramm enable row level security;
alter table bauprogramm_block enable row level security;
drop policy if exists bauprogramm_lesen on bauprogramm;
create policy bauprogramm_lesen on bauprogramm for select using (ist_eingeloggter_benutzer());
drop policy if exists bauprogramm_schreiben on bauprogramm;
create policy bauprogramm_schreiben on bauprogramm for all
  using (recht_wert('plan', 'einsaetze', 'bearbeiten') <> 'K') with check (recht_wert('plan', 'einsaetze', 'bearbeiten') <> 'K');
drop policy if exists bauprogramm_block_lesen on bauprogramm_block;
create policy bauprogramm_block_lesen on bauprogramm_block for select using (ist_eingeloggter_benutzer());
drop policy if exists bauprogramm_block_schreiben on bauprogramm_block;
create policy bauprogramm_block_schreiben on bauprogramm_block for all
  using (recht_wert('plan', 'einsaetze', 'bearbeiten') <> 'K') with check (recht_wert('plan', 'einsaetze', 'bearbeiten') <> 'K');
