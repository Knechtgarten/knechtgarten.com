-- Haupttool «Pool-Konfigurator»: Rechteckbecken planen (Grundriss, Schnitt, 3D, Bauteile, Technik).
-- Eine Planung = eine Variante für einen Kunden; der ganze Stand liegt als JSON in «daten».
-- Versionen: jede festgehaltene oder versendete Fassung als eigene Zeile (versendet = nicht mehr änderbar).

create table if not exists pool_planung (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid references kunde(id) on delete set null,
  bewilligung_id uuid references bewilligung(id) on delete set null,   -- später: Pool ins Baugesuch übernehmen
  variante text not null default 'Variante A',
  daten jsonb not null default '{}',     -- Masse, Bauweise, Abdeckung, Treppe, Technik, Bauteile …
  status text not null default 'planung', -- 'planung' | 'kundenblatt' | 'preisanfrage' | 'zugesagt' | 'archiviert'
  version integer not null default 1,
  erstellt_von uuid references benutzer(id), erstellt_am timestamptz not null default now(),
  geaendert_von uuid references benutzer(id), geaendert_am timestamptz not null default now()
);
create index if not exists pool_planung_kunde on pool_planung(kunde_id);

create table if not exists pool_planung_version (
  id uuid primary key default gen_random_uuid(),
  planung_id uuid not null references pool_planung(id) on delete cascade,
  nr integer not null,
  daten jsonb not null,
  was text,
  versendet boolean not null default false,
  erstellt_von uuid references benutzer(id), erstellt_am timestamptz not null default now(),
  unique (planung_id, nr)
);

alter table pool_planung enable row level security;
alter table pool_planung_version enable row level security;
drop policy if exists pool_planung_alle on pool_planung;
create policy pool_planung_alle on pool_planung for all to authenticated using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
drop policy if exists pool_planung_version_alle on pool_planung_version;
create policy pool_planung_version_alle on pool_planung_version for all to authenticated using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
