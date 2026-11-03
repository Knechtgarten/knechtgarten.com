-- 1) Merkmale bei Personen (firmenweit, Verwaltung › Personen › Merkmale): Projektleiter, Bauführer, Vorarbeiter, Lernende …
--    Ersetzt die eigene Personenliste der Doku-Tools (doku_person bleibt vorerst stehen, wird nicht mehr benutzt).
-- 2) Mitarbeiter-Dokumente: Ordner «für alle» (Mitarbeitende lesen), Dokumentarten pdf (GAV) und abschnitte (Reglement) mit Versionen.

-- Merkmale -------------------------------------------------------------------------------
create table if not exists merkmal (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  schluessel text unique,            -- feste Merkmale, die der Code kennt (projektleiter, bauleiter, vorarbeiter, lernende)
  sortierung integer not null default 0
);
create table if not exists benutzer_merkmal (
  benutzer_id uuid not null references benutzer(id) on delete cascade,
  merkmal_id uuid not null references merkmal(id) on delete cascade,
  primary key (benutzer_id, merkmal_id)
);
alter table benutzer add column if not exists name_dokumente text;   -- voller Name auf Briefen (sonst Anzeigename)
alter table benutzer add column if not exists mail_dokumente text;   -- Mail auf Briefen (z. B. bau@knechtgarten.ch)

alter table merkmal enable row level security;
alter table benutzer_merkmal enable row level security;
drop policy if exists merkmal_lesen on merkmal;
create policy merkmal_lesen on merkmal for select using (ist_eingeloggter_benutzer());
drop policy if exists merkmal_admin on merkmal;
create policy merkmal_admin on merkmal for all using (ist_admin()) with check (ist_admin());
drop policy if exists benutzer_merkmal_lesen on benutzer_merkmal;
create policy benutzer_merkmal_lesen on benutzer_merkmal for select using (ist_eingeloggter_benutzer());
drop policy if exists benutzer_merkmal_admin on benutzer_merkmal;
create policy benutzer_merkmal_admin on benutzer_merkmal for all using (ist_admin()) with check (ist_admin());

insert into merkmal (name, schluessel, sortierung) values
  ('Projektleiter', 'projektleiter', 1), ('Bauführer', 'bauleiter', 2), ('Vorarbeiter', 'vorarbeiter', 3), ('Lernende', 'lernende', 4)
on conflict (schluessel) do nothing;

-- Startwerte aus den Planer-Haken
insert into benutzer_merkmal (benutzer_id, merkmal_id)
select p.benutzer_id, m.id from planer_person p join merkmal m on m.schluessel = 'projektleiter'
where p.ist_projektleiter and p.aktiv and p.benutzer_id is not null on conflict do nothing;
insert into benutzer_merkmal (benutzer_id, merkmal_id)
select p.benutzer_id, m.id from planer_person p join merkmal m on m.schluessel = 'vorarbeiter'
where p.ist_vorarbeiter and p.aktiv and p.benutzer_id is not null on conflict do nothing;

-- voller Name aus dem Planer, wo der Anzeigename nur ein Vorname ist (z. B. «Fabian» → «Fabian Oberholzer»)
update benutzer b set name_dokumente = p.name
from planer_person p
where p.benutzer_id = b.id and p.aktiv and b.name_dokumente is null
  and position(' ' in p.name) > 0 and position(' ' in coalesce(b.anzeigename, '')) = 0;

-- Handy/Mail aus der bisherigen Doku-Personenliste übernehmen (nur eindeutige Treffer, nichts überschreiben)
with z as (
  select d.id as doku_id, d.telefon, d.mail, coalesce(d.benutzer_id,
    (select p.benutzer_id from planer_person p where p.name = d.name and p.benutzer_id is not null limit 1),
    (select b.id from benutzer b where b.anzeigename = d.name or b.name_dokumente = d.name limit 1)) as benutzer_id
  from doku_person d
)
update benutzer b set telefon = coalesce(b.telefon, z.telefon), mail_dokumente = coalesce(b.mail_dokumente, z.mail)
from z where z.benutzer_id = b.id;

-- bestehende Dokumente: Personen-IDs von doku_person auf benutzer umstellen
with z as (
  select d.id::text as alt, coalesce(d.benutzer_id,
    (select p.benutzer_id from planer_person p where p.name = d.name and p.benutzer_id is not null limit 1),
    (select b.id from benutzer b where b.anzeigename = d.name or b.name_dokumente = d.name limit 1))::text as neu
  from doku_person d
)
update doku_dokument x set werte = x.werte
  || case when zp.neu is not null then jsonb_build_object('pl', zp.neu) else '{}'::jsonb end
  || case when zv.neu is not null then jsonb_build_object('va', zv.neu) else '{}'::jsonb end
from doku_dokument y
left join z zp on zp.alt = y.werte->>'pl'
left join z zv on zv.alt = y.werte->>'va'
where x.id = y.id and (zp.neu is not null or zv.neu is not null);

-- Personen für Dokumente (benutzer ist sonst nur für Admin/eigene Zeile lesbar): nur Name, Handy, Mail, Merkmale
create or replace function doku_personen()
returns table (id uuid, name text, telefon text, mail text, merkmale text[])
language sql stable security definer set search_path = public as $$
  select b.id, coalesce(nullif(b.name_dokumente, ''), b.anzeigename), b.telefon,
         coalesce(nullif(b.mail_dokumente, ''), case when b.email ilike '%@knechtgarten.ch' then b.email end),
         array_agg(m.schluessel order by m.sortierung) filter (where m.schluessel is not null)
  from benutzer b join benutzer_merkmal bm on bm.benutzer_id = b.id join merkmal m on m.id = bm.merkmal_id
  where b.aktiv is not false and recht_wert('doku', 'briefe', 'an') = 'J'
  group by b.id
$$;
grant execute on function doku_personen() to authenticated;

-- Mitarbeiter-Dokumente -----------------------------------------------------------------------
alter table doku_ordner add column if not exists fuer_alle boolean not null default false;
alter table doku_vorlage add column if not exists art text not null default 'brief';
alter table doku_vorlage drop constraint if exists doku_vorlage_art_check;
alter table doku_vorlage add constraint doku_vorlage_art_check check (art in ('brief', 'pdf', 'abschnitte'));
alter table doku_vorlage add column if not exists datei_pfad text;   -- aktuelles PDF im Bucket doku-dateien
alter table doku_vorlage add column if not exists stand date;

create table if not exists doku_abschnitt (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references doku_vorlage(id) on delete cascade,
  titel text not null default '',
  html text not null default '',
  sortierung integer not null default 0
);
create table if not exists doku_version (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references doku_vorlage(id) on delete cascade,
  stand date not null default current_date,
  datei_pfad text,
  inhalt jsonb,                        -- Abschnitte zum Zeitpunkt der Version (nur Art «abschnitte»)
  erstellt_von uuid default auth.uid() references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now()
);
alter table doku_abschnitt enable row level security;
alter table doku_version enable row level security;

-- Rechte: Tool für alle sichtbar; Briefe (alle Ordner ausser «für alle») nur mit Schalter «briefe» (Büro)
update recht_eintrag set wert = 'J' where tool_key = 'doku' and bereich_key = '_tool' and aktion = 'sichtbar';
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'doku', 'briefe', 'an', case when g.schluessel = 'buero' then 'J' else 'N' end from recht_gruppe g
on conflict do nothing;

create or replace function doku_ordner_offen(p_ordner uuid) returns boolean language sql stable security definer set search_path = public as $$
  select recht_wert('doku', 'briefe', 'an') = 'J' or exists (select 1 from doku_ordner o where o.id = p_ordner and o.fuer_alle)
$$;

drop policy if exists doku_ordner_lesen on doku_ordner;
create policy doku_ordner_lesen on doku_ordner for select using (fuer_alle or recht_wert('doku', 'briefe', 'an') = 'J');
drop policy if exists doku_vorlage_lesen on doku_vorlage;
create policy doku_vorlage_lesen on doku_vorlage for select using (doku_ordner_offen(ordner_id));
drop policy if exists doku_dokument_alle on doku_dokument;
create policy doku_dokument_alle on doku_dokument for all
  using (recht_wert('doku', 'briefe', 'an') = 'J') with check (recht_wert('doku', 'briefe', 'an') = 'J');
drop policy if exists doku_person_lesen on doku_person;
create policy doku_person_lesen on doku_person for select using (recht_wert('doku', 'briefe', 'an') = 'J');

drop policy if exists doku_abschnitt_lesen on doku_abschnitt;
create policy doku_abschnitt_lesen on doku_abschnitt for select using (exists (select 1 from doku_vorlage v where v.id = vorlage_id and doku_ordner_offen(v.ordner_id)));
drop policy if exists doku_abschnitt_pflegen on doku_abschnitt;
create policy doku_abschnitt_pflegen on doku_abschnitt for all
  using (recht_wert('doku', 'vorlagen', 'an') = 'J') with check (recht_wert('doku', 'vorlagen', 'an') = 'J');
drop policy if exists doku_version_lesen on doku_version;
create policy doku_version_lesen on doku_version for select using (exists (select 1 from doku_vorlage v where v.id = vorlage_id and doku_ordner_offen(v.ordner_id)));
drop policy if exists doku_version_pflegen on doku_version;
create policy doku_version_pflegen on doku_version for all
  using (recht_wert('doku', 'vorlagen', 'an') = 'J') with check (recht_wert('doku', 'vorlagen', 'an') = 'J');

-- Speicher für die PDFs (privat; lesen alle Angemeldeten, schreiben nur mit Recht «Vorlagen bearbeiten»)
insert into storage.buckets (id, name, public) values ('doku-dateien', 'doku-dateien', false) on conflict (id) do nothing;
drop policy if exists doku_dateien_lesen on storage.objects;
create policy doku_dateien_lesen on storage.objects for select using (bucket_id = 'doku-dateien' and ist_eingeloggter_benutzer());
drop policy if exists doku_dateien_schreiben on storage.objects;
create policy doku_dateien_schreiben on storage.objects for insert with check (bucket_id = 'doku-dateien' and recht_wert('doku', 'vorlagen', 'an') = 'J');
drop policy if exists doku_dateien_aendern on storage.objects;
create policy doku_dateien_aendern on storage.objects for update using (bucket_id = 'doku-dateien' and recht_wert('doku', 'vorlagen', 'an') = 'J');
drop policy if exists doku_dateien_loeschen on storage.objects;
create policy doku_dateien_loeschen on storage.objects for delete using (bucket_id = 'doku-dateien' and recht_wert('doku', 'vorlagen', 'an') = 'J');

-- Ordner Mitarbeiter für alle, GAV und Reglement anlegen
update doku_ordner set fuer_alle = true where name = 'Mitarbeiter';
insert into doku_vorlage (ordner_id, schluessel, name, beschreibung, art, sortierung)
select o.id, v.s, v.n, v.b, v.a, v.r from doku_ordner o
cross join (values ('gav', 'Gesamtarbeitsvertrag (GAV)', 'GAV Grüne Branche', 'pdf', 1),
                   ('reglement', 'Reglement / Firmenordnung', 'Arbeitszeit, Spesen, Ferien, Kleider und mehr', 'abschnitte', 2)) v(s, n, b, a, r)
where o.name = 'Mitarbeiter'
on conflict (schluessel) do nothing;
