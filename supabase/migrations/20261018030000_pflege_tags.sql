-- ============================================================================
-- Pflege-Tool: Tags zum Filtern der Kunden
--
-- Zentrale Tag-Liste (pflege_tag). Tags werden in der Verwaltung verknuepft
-- (nicht beim Kunden gepflegt):
--   - Auswahlliste: pflege_feld.tags = { "<Auswahlmoeglichkeit>": "<tag_id>", ... }
--     (mehrere Moeglichkeiten duerfen denselben Tag haben, z. B. alle Waermepumpen-Typen)
--   - Ja/Nein-Feld: pflege_feld.tags = { "ja": "<tag_id>" }
--   - Standardarbeit: pflege_arbeit.tag_id
-- Beim Kunden ergeben sich die Tags automatisch aus seinen Angaben und Arbeiten;
-- jeder Tag zaehlt pro Kunde nur einmal.
-- ============================================================================
create table pflege_tag (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  reihenfolge integer not null default 0,
  erstellt_am timestamptz not null default now()
);
alter table pflege_tag enable row level security;
create policy pflege_tag_lesen on pflege_tag for select using (ist_eingeloggter_benutzer());
create policy pflege_tag_buero_admin on pflege_tag for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

alter table pflege_feld add column tags jsonb not null default '{}'::jsonb;
alter table pflege_arbeit add column tag_id uuid null references pflege_tag(id) on delete set null;

-- Startwert: Tag «Rohnertec», Auswahlmoeglichkeit «Rohnertec» beim Steuergeraet der
-- Bewaesserung, und bei allen mit Rohnertec verknuepften Kunden als Steuergeraet eingetragen
insert into pflege_tag (name, reihenfolge) values ('Rohnertec', 1);
update pflege_feld f set
    optionen = case when f.optionen ? 'Rohnertec' then f.optionen else f.optionen || '["Rohnertec"]'::jsonb end,
    tags = f.tags || jsonb_build_object('Rohnertec', (select id from pflege_tag where name = 'Rohnertec'))
  from pflege_kategorie k
 where k.id = f.kategorie_id and k.sondertabelle = 'bewaesserung' and f.name = 'Steuergerät' and f.typ = 'auswahl';
update pflege_kunde_kategorie kk set werte = kk.werte || jsonb_build_object(f.id::text, 'Rohnertec')
  from pflege_kategorie k, pflege_feld f, pflege_kunde p
 where k.id = kk.kategorie_id and k.sondertabelle = 'bewaesserung' and f.kategorie_id = k.id and f.name = 'Steuergerät'
   and p.kunde_id = kk.kunde_id and p.rohnertec_id is not null and kk.objekt_id is null
   and coalesce(kk.werte ->> f.id::text, '') = '';
