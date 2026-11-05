-- Einsatzplaner: Arbeitszeit nach Saison (jedes Jahr gleich, im Planer anpassbar)
-- Ein Eintrag gilt ab Tag/Monat bis zum nächsten Eintrag. stunden = 0 / start leer = Betrieb geschlossen.
create table if not exists public.planer_arbeitszeit (
  id uuid primary key default gen_random_uuid(),
  ab_monat int not null check (ab_monat between 1 and 12),
  ab_tag int not null check (ab_tag between 1 and 31),
  start text,
  stunden numeric not null default 0,
  erstellt_am timestamptz not null default now(),
  unique (ab_monat, ab_tag)
);
alter table public.planer_arbeitszeit enable row level security;
drop policy if exists planer_arbeitszeit_lesen on public.planer_arbeitszeit;
create policy planer_arbeitszeit_lesen on public.planer_arbeitszeit for select using (ist_eingeloggter_benutzer());
drop policy if exists planer_arbeitszeit_buero on public.planer_arbeitszeit;
create policy planer_arbeitszeit_buero on public.planer_arbeitszeit for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
insert into public.planer_arbeitszeit (ab_monat, ab_tag, start, stunden) values
  (1, 1, '08:00', 8), (2, 9, '07:30', 8.5), (3, 2, '07:00', 9), (11, 16, '07:30', 8.5), (12, 20, null, 0)
on conflict (ab_monat, ab_tag) do nothing;
-- eigene Zeile «Lehrlinge» unter den Hinweisen (Schulferien, Schule, Prüfungen)
insert into public.planer_person (name, gruppe_id, aktiv, sortierung)
select 'Lehrlinge', g.id, true, 15 from public.planer_gruppe g where g.name = 'Allgemein'
  and not exists (select 1 from public.planer_person p where p.gruppe_id = g.id and p.name = 'Lehrlinge');
