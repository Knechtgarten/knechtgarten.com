-- ============================================================================
-- Einsatzplaner Etappe 3: Auftraege und Pendenzen
--
-- planer_auftrag  noch nicht eingeplante Arbeit (wird ein Balken im Plan).
--                 scope 'team' (Gruppe), 'person', 'sammel' (Magazin / Werkhof
--                 & Maschinen fuer alle). Beim Einplanen entsteht ein Einsatz,
--                 der Auftrag wird geloescht; Balken zurueckziehen = wieder Auftrag.
-- planer_pendenz  To-do, wird abgehakt. Ebene Person / Gruppe / Firma,
--                 Spalte 'tag' (Tagespendenz mit Datum, wandert mit bis erledigt)
--                 oder 'lang' (langfristig).
-- Rechte: alle Eingeloggten duerfen lesen und schreiben (internes Team).
-- ============================================================================

create table planer_auftrag (
  id uuid primary key default gen_random_uuid(),
  scope text not null default 'team' check (scope in ('team', 'person', 'sammel')),
  gruppe_id uuid null references planer_gruppe(id) on delete set null,
  person_id uuid null references planer_person(id) on delete cascade,
  sammel text null check (sammel in ('magazin', 'werkhof')),
  kunde_id uuid null references kunde(id) on delete set null,
  titel text not null,
  notiz text null,
  dauer text not null default 'tag' check (dauer in ('kurz', 'tag', 'mehr')),
  dauer_tage numeric null,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);

create table planer_pendenz (
  id uuid primary key default gen_random_uuid(),
  ebene text not null default 'person' check (ebene in ('person', 'gruppe', 'firma')),
  person_id uuid null references planer_person(id) on delete cascade,
  gruppe_id uuid null references planer_gruppe(id) on delete cascade,
  spalte text not null default 'tag' check (spalte in ('tag', 'lang')),
  text text not null,
  tag date null,
  erledigt boolean not null default false,
  erledigt_am timestamptz null,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);
create index planer_pendenz_person_idx on planer_pendenz (person_id);

alter table planer_auftrag enable row level security;
alter table planer_pendenz enable row level security;
create policy planer_auftrag_voll on planer_auftrag for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy planer_pendenz_voll on planer_pendenz for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

alter publication supabase_realtime add table planer_auftrag, planer_pendenz;
