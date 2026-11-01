-- ============================================================================
-- Einsatzplaner: wichtige Info pro Termin und Tag (ersetzt die Icons bei den Mitarbeitenden)
-- Im Planer: kleines gelbes Feld im Termin an diesem Tag, Text im Mouse-over / per Klick.
-- Rechte wie beim Einsatz selbst (planer_darf_person der Person des Einsatzes).
-- ============================================================================
create table if not exists planer_einsatz_info (
  id uuid primary key default gen_random_uuid(),
  einsatz_id uuid not null references planer_einsatz(id) on delete cascade,
  tag date not null,
  text text not null,
  erstellt_von uuid default auth.uid() references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now(),
  unique (einsatz_id, tag)
);
alter table planer_einsatz_info enable row level security;
drop policy if exists planer_einsatz_info_lesen on planer_einsatz_info;
drop policy if exists planer_einsatz_info_schreiben on planer_einsatz_info;
create policy planer_einsatz_info_lesen on planer_einsatz_info for select using (ist_eingeloggter_benutzer());
create policy planer_einsatz_info_schreiben on planer_einsatz_info for all
  using (planer_darf_person((select person_id from planer_einsatz e where e.id = einsatz_id)))
  with check (planer_darf_person((select person_id from planer_einsatz e where e.id = einsatz_id)));

-- Icons bei den Mitarbeitenden fallen weg (Allgemein-Zeilen behalten ihre Icons): die zwei bestehenden löschen
delete from planer_markierung m using planer_person p left join planer_gruppe g on g.id = p.gruppe_id
where m.person_id = p.id and coalesce(g.name, '') not ilike 'allgemein%';
