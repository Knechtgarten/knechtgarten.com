-- Werkzeuge (Rechner & Hilfsmittel): Favoriten pro Person, Rechte pro Werkzeug,
-- dazu eigene Handy-Anordnung der Startseite (Widgets per Drag & Drop).

-- Favoriten -------------------------------------------------------------------
create table if not exists werkzeug_favorit (
  benutzer_id uuid not null default auth.uid() references benutzer(id) on delete cascade,
  werkzeug_key text not null,
  sortierung integer not null default 0,
  erstellt_am timestamptz not null default now(),
  primary key (benutzer_id, werkzeug_key)
);
alter table werkzeug_favorit enable row level security;
drop policy if exists werkzeug_favorit_eigene on werkzeug_favorit;
create policy werkzeug_favorit_eigene on werkzeug_favorit for all
  using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());

-- Startseite: eigene Anordnung auch auf dem Handy -----------------------------
alter table startseite_layout add column if not exists layout_handy jsonb;
alter table startseite_layout alter column layout drop not null;

-- Rechte: Tool sichtbar + ein Schalter pro Werkzeug, für alle Gruppen «Ja» ---
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'werkzeuge', w.k, case when w.k = '_tool' then 'sichtbar' else 'an' end, 'J'
from recht_gruppe g
cross join (values ('_tool'), ('pool_chlor'), ('pool_salz'), ('pool_alk'), ('pool_afm'), ('pool_volumen'),
                   ('allg_volumen'), ('allg_gefaelle')) as w(k)
on conflict do nothing;
