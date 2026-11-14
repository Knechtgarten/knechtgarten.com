-- Bereiche pro Kunde (A Südseite, B Nordseite …): gelten für alle Offerten dieses Kunden.
-- Buchstabe fest (nie neu vergeben), Name änderbar; ausgeblendet = nicht mehr für neue Offerten.
create table if not exists public.kunde_bereich (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references public.kunde(id) on delete cascade,
  buchstabe text not null,
  name text,
  ausgeblendet boolean not null default false,
  erstellt_am timestamptz not null default now(),
  erstellt_von uuid default auth.uid(),
  unique (kunde_id, buchstabe)
);
alter table public.kunde_bereich enable row level security;
drop policy if exists kunde_bereich_alle on public.kunde_bereich;
create policy kunde_bereich_alle on public.kunde_bereich for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

alter table public.offerte add column if not exists bereich_id uuid references public.kunde_bereich(id) on delete set null;
create index if not exists offerte_bereich_id_idx on public.offerte(bereich_id);
-- (offerte.bereich als Text war noch leer und wird nicht mehr verwendet)
