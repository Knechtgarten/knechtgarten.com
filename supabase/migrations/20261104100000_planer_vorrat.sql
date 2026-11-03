-- Arbeitsvorrat im Einsatzplaner: zugesagte, noch nicht terminierte Arbeiten (Streifen oben im Planer).
-- Die Lage im Streifen ist kein Datum: die Balken stapeln sich selber (älteste oben links).
-- Runterziehen auf eine Person = Planer-Balken (planer_einsatz), der Vorrat-Eintrag wird dabei gelöscht.

create table if not exists planer_vorrat (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid references kunde(id) on delete set null,
  titel text,
  tage numeric not null default 5 check (tage > 0),
  bereich text not null default 'bau' check (bereich in ('bau', 'pflege')),
  geschaetzt boolean not null default false,          -- Länge nur geschätzt (provisorisch)
  projektleiter_id uuid references planer_person(id) on delete set null,
  notiz text,
  erstellt_von uuid references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now()
);

alter table planer_vorrat enable row level security;
drop policy if exists planer_vorrat_voll on planer_vorrat;
create policy planer_vorrat_voll on planer_vorrat for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
alter publication supabase_realtime add table planer_vorrat;
