-- ============================================================================
-- Pendenzentool, Etappe 1: Board > Liste > Gruppe > Pendenz
--
-- pendenz_art           Pendenzenarten (fixer Titel + Icon, Standard-Farbe). funktion = keine
--                       Art, sondern Funktion (Team-box: andere schreiben direkt rein).
-- pendenz_board         Board einer Person, gemeinsames Board oder Firma-Board
-- pendenz_board_mitglied  wer ein gemeinsames Board sieht
-- pendenz_liste         Liste auf dem Blatt: gehoert zu einer Art ODER ist Zeitliste (1 Heute,
--                       2 Diese Woche, 3 Dieser Monat, 4 Dieses Jahr). bereich = zeit|mitte|team,
--                       x/y = Lage im 20-px-Raster.
-- pendenz_gruppe        aufklappbare Gruppe in einer Liste (z. B. pro Person bei Besprechen)
-- pendenz               eine Zeile. zeit 0-4 = Prioritaet (0 = irgendwann), notiz = HTML.
--                       Bleibt in ihrer Liste, Zeitlisten zeigen sie zusaetzlich.
-- pendenz_datei         Fotos / Anhaenge / Mail-PDF (Bucket pendenz-dateien, privat)
-- pendenz_benutzer      persoenliche Einstellungen: Oeffnen als Fenster/rechts, Bereichsbreiten,
--                       eigene Farben pro Art, Notizzettel
-- Rechte: alle Eingeloggten duerfen lesen und schreiben (internes Team).
-- ============================================================================

create table pendenz_art (
  id text primary key,
  titel text not null,
  icon text not null,
  farbe text not null,
  sortierung int not null default 0,
  funktion boolean not null default false,
  aktiv boolean not null default true
);

insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion) values
  ('mail',     'Mails',               'brief',      '#B07A4A', 10,  false),
  ('offerte',  'Offerten',            'dok',        '#5F8A6B', 20,  false),
  ('avor',     'AVOR',                'plan',       '#7A8F4E', 30,  false),
  ('besprechen','Besprechen',         'leute',      '#6B5F8A', 40,  false),
  ('kunden',   'Kunden',              'telefon',    '#9A6B7E', 50,  false),
  ('admin',    'Administration',      'ordner',     '#323E4E', 60,  false),
  ('ki',       'KI-EDV',              'funken',     '#3F6E8C', 70,  false),
  ('marketing','Marketing',           'stern',      '#8E5B4A', 80,  false),
  ('werkhof',  'Werkhof & Fahrzeuge', 'schluessel', '#9A8A3A', 90,  false),
  ('personal', 'Personal',            'person',     '#8A6F5F', 100, false),
  ('team',     'Team-box',            'briefOffen', '#4C5C70', 110, true);

create table pendenz_board (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  typ text not null default 'person' check (typ in ('person', 'gemeinsam', 'firma')),
  besitzer_id uuid null references benutzer(id) on delete cascade on update cascade,
  mail_kuerzel text null unique,
  erstellt_am timestamptz not null default now()
);
create unique index pendenz_board_person_idx on pendenz_board (besitzer_id) where typ = 'person';

create table pendenz_board_mitglied (
  board_id uuid not null references pendenz_board(id) on delete cascade,
  benutzer_id uuid not null references benutzer(id) on delete cascade on update cascade,
  primary key (board_id, benutzer_id)
);

create table pendenz_liste (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references pendenz_board(id) on delete cascade,
  art_id text null references pendenz_art(id),
  zeit smallint null check (zeit between 1 and 4),
  titel text not null,
  bereich text not null default 'mitte' check (bereich in ('zeit', 'mitte', 'team')),
  x int not null default 20,
  y int not null default 20,
  zu boolean not null default false,
  erstellt_am timestamptz not null default now(),
  constraint pendenz_liste_art_oder_zeit check (num_nonnulls(art_id, zeit) = 1)
);
create index pendenz_liste_board_idx on pendenz_liste (board_id);

create table pendenz_gruppe (
  id uuid primary key default gen_random_uuid(),
  liste_id uuid not null references pendenz_liste(id) on delete cascade,
  titel text not null,
  zu boolean not null default false,
  sortierung int not null default 0
);
create index pendenz_gruppe_liste_idx on pendenz_gruppe (liste_id);

create table pendenz (
  id uuid primary key default gen_random_uuid(),
  liste_id uuid not null references pendenz_liste(id) on delete cascade,
  gruppe_id uuid null references pendenz_gruppe(id) on delete set null,
  titel text not null,
  zeit smallint not null default 0 check (zeit between 0 and 4),
  notiz text null,
  sortierung double precision not null default 0,
  zeit_sortierung double precision null,
  erledigt boolean not null default false,
  erledigt_am timestamptz null,
  erledigt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);
create index pendenz_liste_idx on pendenz (liste_id);

create table pendenz_datei (
  id uuid primary key default gen_random_uuid(),
  pendenz_id uuid not null references pendenz(id) on delete cascade,
  art text not null default 'datei' check (art in ('foto', 'datei', 'mail')),
  name text not null,
  storage_pfad text not null,
  erstellt_am timestamptz not null default now()
);
create index pendenz_datei_pendenz_idx on pendenz_datei (pendenz_id);

create table pendenz_benutzer (
  benutzer_id uuid primary key references benutzer(id) on delete cascade on update cascade,
  oeffnen text not null default 'fenster' check (oeffnen in ('fenster', 'rechts')),
  breiten jsonb not null default '{}'::jsonb,
  farben jsonb not null default '{}'::jsonb,
  notizzettel text null
);

alter table pendenz_art enable row level security;
alter table pendenz_board enable row level security;
alter table pendenz_board_mitglied enable row level security;
alter table pendenz_liste enable row level security;
alter table pendenz_gruppe enable row level security;
alter table pendenz enable row level security;
alter table pendenz_datei enable row level security;
alter table pendenz_benutzer enable row level security;
create policy pendenz_art_voll on pendenz_art for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_board_voll on pendenz_board for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_board_mitglied_voll on pendenz_board_mitglied for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_liste_voll on pendenz_liste for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_gruppe_voll on pendenz_gruppe for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_voll on pendenz for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_datei_voll on pendenz_datei for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy pendenz_benutzer_eigen on pendenz_benutzer for all using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());

-- Fotos / Anhaenge: Pfad <pendenz_id>/<datei_id>.<ext>
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pendenz-dateien', 'pendenz-dateien', false, 20971520, null)
on conflict (id) do nothing;
create policy "pendenz-dateien lesen" on storage.objects
  for select using (bucket_id = 'pendenz-dateien' and ist_eingeloggter_benutzer());
create policy "pendenz-dateien hochladen" on storage.objects
  for insert with check (bucket_id = 'pendenz-dateien' and ist_eingeloggter_benutzer());
create policy "pendenz-dateien loeschen" on storage.objects
  for delete using (bucket_id = 'pendenz-dateien' and ist_eingeloggter_benutzer());
