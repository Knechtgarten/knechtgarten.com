-- Google-Drive-Ordner pro Kunde und Jahr (Verknüpfung über die Ordner-ID, Name nur zur Anzeige)
create table if not exists public.kunde_ordner (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references public.kunde(id) on delete cascade,
  jahr int,                       -- null = Stammordner (über mehrere Jahre)
  drive_id text not null,
  name text,
  erstellt_von uuid default auth.uid(),
  erstellt_am timestamptz not null default now(),
  unique (kunde_id, drive_id)
);
create index if not exists kunde_ordner_kunde on public.kunde_ordner (kunde_id);
alter table public.kunde_ordner enable row level security;
drop policy if exists kunde_ordner_alle on public.kunde_ordner;
create policy kunde_ordner_alle on public.kunde_ordner for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
