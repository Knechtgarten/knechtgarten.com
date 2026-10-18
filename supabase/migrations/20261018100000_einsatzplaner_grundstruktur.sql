-- ============================================================================
-- Einsatzplaner Etappe 1 (Ersatz Tom's Planner): Grundstruktur
--
-- planer_gruppe   Zeilengruppen (Equipe Gartenbau, Gartenpflege/Service, Lernende ...)
-- planer_person   eine Zeile im Plan. Eigene Liste, weil Lernende, Temporaere,
--                 Schnupperlehrlinge usw. kein Login haben. benutzer_id ist
--                 optional: ist sie gesetzt, darf diese Person ihre eigene Zeile
--                 bearbeiten (Mitarbeitende / Service-Team).
-- planer_einsatz  Baustelle, Termin, Absenz, Werkhof/intern, Mithilfe
--                 beginn/ende = echte Zeitpunkte. Halbtage = 06-12 / 12-18 Uhr.
-- planer_serie    wiederkehrende Termine (Schule, Teilzeit-Frei, Bausitzung)
-- planer_feiertag freie Tage fuer alle (Feiertage, Betriebsferien)
-- planer_datei    Fotos / PDF zu einem Einsatz (Bucket planer-dateien, privat)
--
-- Rechte: lesen alle Eingeloggten. Admin + Buero-Team duerfen alles.
-- Mitarbeitende / Service-Team nur Einsaetze und Serien auf der eigenen Zeile.
-- ============================================================================

create table planer_gruppe (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sortierung int not null default 0,
  erstellt_am timestamptz not null default now()
);

create table planer_person (
  id uuid primary key default gen_random_uuid(),
  gruppe_id uuid null references planer_gruppe(id) on delete set null,
  name text not null,
  kuerzel text null,
  zusatz text null,                      -- z.B. «2. Lj.», «80 %», «Platzhalter»
  farbe text null,                       -- Balkenfarbe (Vorarbeiter / Projektleiter)
  ist_vorarbeiter boolean not null default false,
  ist_projektleiter boolean not null default false,
  benutzer_id uuid null references benutzer(id) on delete set null on update cascade,
  sortierung int not null default 0,
  aktiv boolean not null default true,
  erstellt_am timestamptz not null default now()
);
create index planer_person_gruppe_idx on planer_person (gruppe_id);
create unique index planer_person_benutzer_uidx on planer_person (benutzer_id) where benutzer_id is not null;

create table planer_einsatz (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references planer_person(id) on delete cascade,
  art text not null default 'baustelle' check (art in ('baustelle', 'termin', 'absenz', 'intern', 'hilfe')),
  beginn timestamptz not null,
  ende timestamptz not null,
  kunde_id uuid null references kunde(id) on delete set null,
  titel text null,                       -- wenn kein Kunde: «Ferien», «Werkhof», «Kurs ...»
  notiz text null,
  projektleiter_id uuid null references planer_person(id) on delete set null,
  mit_einsatz_id uuid null references planer_einsatz(id) on delete set null,  -- Mithilfe bei Baustelle X
  allein boolean not null default false,
  abgemacht boolean not null default true,   -- false = «noch nicht abgemacht» (gestreift)
  soll_tage numeric null,                -- geplante Arbeitstage (zeigt Fehlbetrag bei Unterbruch)
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now(),
  check (ende > beginn)
);
create index planer_einsatz_person_idx on planer_einsatz (person_id);
create index planer_einsatz_zeit_idx on planer_einsatz (beginn, ende);
create index planer_einsatz_mit_idx on planer_einsatz (mit_einsatz_id);

create table planer_serie (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references planer_person(id) on delete cascade,
  art text not null default 'absenz' check (art in ('termin', 'absenz', 'intern')),
  titel text not null,
  wochentag int not null check (wochentag between 1 and 7),   -- 1 = Montag
  teil text not null default 'tag' check (teil in ('tag', 'vm', 'nm')),
  alle_zwei_wochen boolean not null default false,
  von date not null,
  bis date null,
  ausnahmen date[] not null default '{}',   -- einzelne geloeschte Termine
  erstellt_am timestamptz not null default now()
);
create index planer_serie_person_idx on planer_serie (person_id);

create table planer_feiertag (
  datum date primary key,
  name text not null
);

create table planer_datei (
  id uuid primary key default gen_random_uuid(),
  einsatz_id uuid not null references planer_einsatz(id) on delete cascade,
  art text not null check (art in ('foto', 'pdf')),
  name text not null,
  storage_pfad text not null,
  erstellt_am timestamptz not null default now()
);
create index planer_datei_einsatz_idx on planer_datei (einsatz_id);

-- geaendert_am automatisch nachfuehren
create or replace function planer_touch()
returns trigger language plpgsql as $$
begin new.geaendert_am := now(); return new; end; $$;
create trigger planer_einsatz_touch before update on planer_einsatz
  for each row execute function planer_touch();

-- Darf der angemeldete Benutzer diese Zeile bearbeiten?
create or replace function planer_darf_person(p uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select ist_buero_oder_admin()
      or exists (select 1 from planer_person pp
                 join benutzer b on b.id = pp.benutzer_id
                 where pp.id = p and b.id = auth.uid() and b.aktiv and b.rolle is not null);
$$;
revoke all on function planer_darf_person(uuid) from public, anon;
grant execute on function planer_darf_person(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
alter table planer_gruppe enable row level security;
alter table planer_person enable row level security;
alter table planer_einsatz enable row level security;
alter table planer_serie enable row level security;
alter table planer_feiertag enable row level security;
alter table planer_datei enable row level security;

create policy planer_gruppe_lesen on planer_gruppe for select using (ist_eingeloggter_benutzer());
create policy planer_gruppe_buero on planer_gruppe for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy planer_person_lesen on planer_person for select using (ist_eingeloggter_benutzer());
create policy planer_person_buero on planer_person for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy planer_feiertag_lesen on planer_feiertag for select using (ist_eingeloggter_benutzer());
create policy planer_feiertag_buero on planer_feiertag for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

create policy planer_einsatz_lesen on planer_einsatz for select using (ist_eingeloggter_benutzer());
create policy planer_einsatz_schreiben on planer_einsatz for insert with check (planer_darf_person(person_id));
create policy planer_einsatz_aendern on planer_einsatz for update using (planer_darf_person(person_id)) with check (planer_darf_person(person_id));
create policy planer_einsatz_loeschen on planer_einsatz for delete using (planer_darf_person(person_id));

create policy planer_serie_lesen on planer_serie for select using (ist_eingeloggter_benutzer());
create policy planer_serie_schreiben on planer_serie for insert with check (planer_darf_person(person_id));
create policy planer_serie_aendern on planer_serie for update using (planer_darf_person(person_id)) with check (planer_darf_person(person_id));
create policy planer_serie_loeschen on planer_serie for delete using (planer_darf_person(person_id));

create policy planer_datei_lesen on planer_datei for select using (ist_eingeloggter_benutzer());
create policy planer_datei_schreiben on planer_datei for all
  using (exists (select 1 from planer_einsatz e where e.id = einsatz_id and planer_darf_person(e.person_id)))
  with check (exists (select 1 from planer_einsatz e where e.id = einsatz_id and planer_darf_person(e.person_id)));

-- ----------------------------------------------------------------------------
-- Live-Abgleich: Aenderungen erscheinen sofort bei allen offenen Planern
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table planer_einsatz, planer_serie, planer_person, planer_gruppe, planer_feiertag;

-- ----------------------------------------------------------------------------
-- Speicher fuer Fotos / PDF (privat, Anzeige ueber signierte Links)
-- Pfad: <einsatz_id>/<datei_id>.<ext>
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('planer-dateien', 'planer-dateien', false, 20971520, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do nothing;

create policy "planer-dateien lesen" on storage.objects
  for select using (bucket_id = 'planer-dateien' and ist_eingeloggter_benutzer());
create policy "planer-dateien hochladen" on storage.objects
  for insert with check (bucket_id = 'planer-dateien' and ist_eingeloggter_benutzer());
create policy "planer-dateien loeschen" on storage.objects
  for delete using (bucket_id = 'planer-dateien' and ist_eingeloggter_benutzer());

-- ----------------------------------------------------------------------------
-- Startwerte: Gruppen (leer, Personen erfasst Stefan) und Feiertage Kanton Bern
-- ----------------------------------------------------------------------------
insert into planer_gruppe (name, sortierung) values
  ('Equipe Gartenbau', 10), ('Gartenpflege / Service', 20), ('Pool / Wasser', 30),
  ('Lernende / Mitarbeitende', 40), ('Büro', 50), ('Schnupperlehrlinge', 60);

insert into planer_feiertag (datum, name) values
  ('2026-12-25', 'Weihnachten'), ('2026-12-26', 'Stephanstag'),
  ('2027-01-01', 'Neujahr'), ('2027-01-02', 'Berchtoldstag'),
  ('2027-03-26', 'Karfreitag'), ('2027-03-29', 'Ostermontag'),
  ('2027-05-06', 'Auffahrt'), ('2027-05-17', 'Pfingstmontag'),
  ('2027-08-01', 'Bundesfeier'), ('2027-12-25', 'Weihnachten'), ('2027-12-26', 'Stephanstag')
on conflict (datum) do nothing;
