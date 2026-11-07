-- Baureglemente der Gemeinden (Kanton Bern): einmal pro Gemeinde von der KI gelesen (Links aus dem ÖREB-Auszug),
-- gespeichert als Zonentabelle + Themen mit Artikel. Pro Gesuch die passende Zone in bewilligung.reglement.
create table if not exists baureglement (
  bfs_nr integer primary key,
  gemeinde text not null,
  urls jsonb not null default '[]',          -- [{ titel, url }] aus dem ÖREB-Auszug
  status text not null default 'laeuft',     -- 'laeuft' | 'fertig' | 'fehler'
  auszug jsonb,                              -- { stand, zonen: [...], themen: [...] }
  fehler text,
  modell text,
  erstellt_am timestamptz not null default now(),
  aktualisiert_am timestamptz not null default now()
);
alter table baureglement enable row level security;
drop policy if exists baureglement_lesen on baureglement;
create policy baureglement_lesen on baureglement for select to authenticated using (ist_buero_oder_admin());
-- geschrieben wird nur von der Edge Function «baureglement» (Service-Rolle)

alter table bewilligung add column if not exists reglement jsonb not null default '{}';   -- { bfs_nr, zone_oereb, zone_index }
