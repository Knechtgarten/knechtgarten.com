-- Fotos Baustelle (Handy): Standort der Kunden für die Vorauswahl der Baustelle (WGS84, aus geo.admin, einmal gemerkt)
-- und ein Protokoll, wer wann wie viele Fotos wohin abgelegt hat.
alter table kunde add column if not exists geo_lat double precision;
alter table kunde add column if not exists geo_lon double precision;
alter table kunde add column if not exists geo_stand timestamptz;

create table if not exists foto_ablage (
  id uuid primary key default gen_random_uuid(),
  benutzer_id uuid references benutzer(id) on delete set null,
  kunde_id uuid references kunde(id) on delete cascade,
  drive_datei_id text, dateiname text, ordner_id text,
  lat double precision, lon double precision,
  erstellt_am timestamptz not null default now()
);
create index if not exists foto_ablage_kunde on foto_ablage(kunde_id, erstellt_am desc);
alter table foto_ablage enable row level security;
drop policy if exists foto_ablage_lesen on foto_ablage;
create policy foto_ablage_lesen on foto_ablage for select to authenticated using (benutzer_id = auth.uid() or ist_buero_oder_admin());
-- geschrieben wird nur von der Edge Function «fotos» (Service-Rolle)
