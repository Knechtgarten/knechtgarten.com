-- Doku-Tools (Dokument-Generator): Ordner > Dokumenttypen (Vorlagen), zentrale Personenliste,
-- zuletzt erstellte Dokumente als Kopiervorlage (kein Archiv; das PDF gehört in den Kunden-Drive).
-- Felder und Daten-Fenster pro Dokumenttyp stehen im Code (app/kg-doku.js), hier nur Text und Daten.

-- Ordner ------------------------------------------------------------------------
create table if not exists doku_ordner (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  farbe text not null default 'grau',          -- Familie aus KG.palette
  sortierung integer not null default 0
);

-- Dokumenttypen: schluessel = Typ im Code (Felder, Daten-Fenster), html = Brieftext mit Feld-Platzhaltern
create table if not exists doku_vorlage (
  id uuid primary key default gen_random_uuid(),
  ordner_id uuid not null references doku_ordner(id) on delete restrict,
  schluessel text not null unique,
  name text not null,
  beschreibung text,
  html text not null default '',
  sortierung integer not null default 0,
  geaendert_am timestamptz not null default now(),
  geaendert_von uuid references benutzer(id) on delete set null
);

-- Personen für Kontaktblöcke (zentral für das ganze Tool) ------------------------
create table if not exists doku_person (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  rolle text not null check (rolle in ('projektleiter', 'bauleiter', 'vorarbeiter')),
  telefon text,
  mail text,
  benutzer_id uuid references benutzer(id) on delete set null,   -- Login → beim Ausfüllen «ich» vorausgewählt
  aktiv boolean not null default true,
  sortierung integer not null default 0
);
-- 'bauleiter' = Anzeige «Bauführer»

-- Erstellte Dokumente (Kopiervorlage) ---------------------------------------------
create table if not exists doku_dokument (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references doku_vorlage(id) on delete cascade,
  kunde_id uuid references kunde(id) on delete set null,
  werte jsonb not null default '{}'::jsonb,
  adresse text,
  datum date,
  erstellt_von uuid default auth.uid() references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create index if not exists doku_dokument_neu on doku_dokument (geaendert_am desc);

-- Zugriff -----------------------------------------------------------------------
alter table doku_ordner enable row level security;
alter table doku_vorlage enable row level security;
alter table doku_person enable row level security;
alter table doku_dokument enable row level security;

drop policy if exists doku_ordner_lesen on doku_ordner;
create policy doku_ordner_lesen on doku_ordner for select using (recht_wert('doku', '_tool', 'sichtbar') = 'J');
drop policy if exists doku_ordner_pflegen on doku_ordner;
create policy doku_ordner_pflegen on doku_ordner for all
  using (recht_wert('doku', 'vorlagen', 'an') = 'J') with check (recht_wert('doku', 'vorlagen', 'an') = 'J');

drop policy if exists doku_vorlage_lesen on doku_vorlage;
create policy doku_vorlage_lesen on doku_vorlage for select using (recht_wert('doku', '_tool', 'sichtbar') = 'J');
drop policy if exists doku_vorlage_pflegen on doku_vorlage;
create policy doku_vorlage_pflegen on doku_vorlage for update
  using (recht_wert('doku', 'vorlagen', 'an') = 'J') with check (recht_wert('doku', 'vorlagen', 'an') = 'J');

drop policy if exists doku_person_lesen on doku_person;
create policy doku_person_lesen on doku_person for select using (recht_wert('doku', '_tool', 'sichtbar') = 'J');
drop policy if exists doku_person_pflegen on doku_person;
create policy doku_person_pflegen on doku_person for all
  using (recht_wert('doku', 'personen', 'an') = 'J') with check (recht_wert('doku', 'personen', 'an') = 'J');

drop policy if exists doku_dokument_alle on doku_dokument;
create policy doku_dokument_alle on doku_dokument for all
  using (recht_wert('doku', '_tool', 'sichtbar') = 'J') with check (recht_wert('doku', '_tool', 'sichtbar') = 'J');

-- Rechte: Tool fürs Büro (Admin immer); Vorlagen bearbeiten und Personen pflegen nur Admin
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'doku', '_tool', 'sichtbar', case when g.schluessel = 'buero' then 'J' else 'N' end from recht_gruppe g
on conflict do nothing;
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'doku', b.k, 'an', 'N' from recht_gruppe g cross join (values ('vorlagen'), ('personen')) as b(k)
on conflict do nothing;

-- Startdaten ----------------------------------------------------------------------
insert into doku_ordner (name, farbe, sortierung)
select * from (values ('Nachbarschaft', 'beere', 1), ('Transport', 'erde', 2), ('Mitarbeiter', 'violett', 3), ('Kunden', 'blau', 4)) v(n, f, s)
where not exists (select 1 from doku_ordner);

insert into doku_vorlage (ordner_id, schluessel, name, beschreibung, html, sortierung)
select o.id, 'helikopter', 'Helikoptereinsatz', 'Info für die Briefkästen rundum: Datum, Zeit, Vorsichtsmassnahmen',
'<h2>Helikoptereinsatz in Ihrer Nachbarschaft</h2>
<p>Sehr geehrte Nachbarinnen und Nachbarn</p>
<p>Am <span data-f="datum"></span> <span data-f="zeit"></span> führen wir an der Liegenschaft <span data-f="kunde_adresse"></span> Arbeiten mit einem Helikopter aus. Dabei kann es zu starken Luftstössen kommen.</p>
<p>Bitte treffen Sie zum Schutz Ihrer Gegenstände und Tiere folgende Vorsichtsmassnahmen:</p>
<ul><li>Fenster, Dachfenster und Balkontüren schliessen</li><li>Balkonstoren und Rollläden einziehen</li><li>Freistehende, leichte oder grossflächige Gegenstände fixieren</li><li>Leichte Blumenkisten von Balkon und Fenstersims entfernen</li><li>Sonnenschirme, Abdeckplanen usw. beschweren oder wegräumen</li><li>Gartenmöbel sichern</li><li>Freilaufende Tiere im Stall unterbringen, Haustiere im Haus behalten</li></ul>
<p>Aus Wettergründen kann der Einsatz verschoben werden. Wir informieren Sie rechtzeitig über einen neuen Termin.</p>
<p>Besten Dank für Ihr Verständnis. Bei Fragen wenden Sie sich bitte direkt an mich.</p>
<p>Freundliche Grüsse</p>
<div data-f="pl_block"></div><div data-f="va_block"></div>', 1
from doku_ordner o where o.name = 'Nachbarschaft'
on conflict (schluessel) do nothing;

-- Personen aus den bisherigen Vorlagen (Login nur bei eindeutigem Namen verknüpft)
insert into doku_person (name, rolle, telefon, mail, benutzer_id, sortierung)
select v.n, v.r, v.t, v.m, (select b.id from benutzer b where b.anzeigename = v.n and b.aktiv limit 1), v.s
from (values ('Benjamin Habegger', 'bauleiter', '079 332 17 13', 'bau@knechtgarten.ch', 1),
             ('Fabian Oberholzer', 'projektleiter', '079 746 32 20', 'fabian.oberholzer@knechtgarten.ch', 2),
             ('Timo Jost', 'vorarbeiter', '079 326 69 54', null, 3)) v(n, r, t, m, s)
where not exists (select 1 from doku_person);
