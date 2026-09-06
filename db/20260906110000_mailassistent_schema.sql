-- ============================================================================
-- Mail-Assistent - Datenbank-Grundlage (nur Struktur, keine Inhalte).
--
-- Neue Kachel "Tools" auf der Startseite (sichtbar nur fuer Buero-Team +
-- Admin) fuehrt zur Tools-Uebersichtsseite, dort als erster Eintrag der
-- Mail-Assistent. Alle Tabellen fuer dessen Verwaltungsseite: Schreibstil,
-- Firmendaten, Mail-Vorlagen (Verfassen/Antworten, inkl. Rueckfrage-Typ mit
-- mehreren Antwort-Zweigen), Distanzlogik (Projekttypen/Stufen/Partner-
-- betriebe), Sonderfaelle (inkl. Ausnahme-Verknuepfung + Auffangfall),
-- Nachbessern-Buttons, Nutzungs-Log, Einstellungen.
--
-- Bewusst OHNE Inhalte befuellt (Entscheid Stefan, 2026-09-06): Schreibstil,
-- Firmendaten, Mail-Vorlagen, Sonderfaelle, Distanzlogik-Projekttypen/Stufen
-- und Partnerbetriebe werden vollstaendig ueber die Verwaltungsseite selbst
-- erfasst, nicht per Migration aus dem alten Google Doc uebernommen. Vier
-- Tabellen brauchen trotzdem eine leere Start-Zeile (kein Inhalt, nur eine
-- Zeile zum Bearbeiten), weil die Verwaltungsseite dort spaeter update statt
-- insert macht: mailassistent_schreibstil, mailassistent_firmendaten,
-- mailassistent_distanzlogik_meta, mailassistent_einstellungen.
--
-- Wichtige strukturelle Entscheide aus der Konzeption (bleiben gueltig, auch
-- ohne Startinhalte):
--  - "Kontaktanfrage" ist keine eigene Vorlage (kein eigener Text), sondern
--    nur der Ausloeser fuer die Distanzlogik - deren Trigger-Kriterium lebt
--    direkt bei mailassistent_distanzlogik_meta.wann_anwenden.
--  - Personalbewerbung (und aehnliche Faelle) sind EIN Vorlage-Eintrag mit
--    Rueckfrage (mehrere Antwort-Zweige in mailassistent_vorlage_antwort),
--    nicht mehrere getrennte Sonderfaelle - sonst widerspruechliche Anleitung
--    fuer die KI.
--  - Eine Ausnahme wird ueber mailassistent_sonderfall.ist_ausnahme_von fest
--    mit ihrer Hauptregel verknuepft, nicht nur per Fliesstext-Verweis -
--    sonst koennte sie beim gezielten Abruf verloren gehen.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Rollen-Helfer: Buero-Team ODER Admin - Sichtbarkeit der Tools-Kachel und
-- Schreibzugriff auf alle Mail-Assistent-Tabellen unten.
-- ----------------------------------------------------------------------------
create or replace function ist_buero_oder_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid() and rolle in ('admin','buero_team'));
$$;

-- ----------------------------------------------------------------------------
-- 1. Startseite: neue Kachel "Tools". "Berechnungstool" wird zu "Rechner"
-- umbenannt (vermeidet Doppelung mit "-tool" im Namen der neuen Kachel).
-- Das ist Navigation/Struktur, keine Mail-Assistent-Inhalte.
-- ----------------------------------------------------------------------------
insert into modul_sichtbarkeit
  (modul_key, name, kurzname, titel_mittel, text_gross, icon_key, hintergrund,
   fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values
  ('tools', 'Tools', 'Tools', 'Tools',
   'Kleine Helfer fuer den Arbeitsalltag, unabhaengig vom Offertentool.',
   'mail', 'grau_dunkel', true, false, false);

update modul_sichtbarkeit
  set name = 'Rechner', titel_mittel = 'Rechner', kurzname = 'Rechner'
  where modul_key = 'berechnungstool';

-- ----------------------------------------------------------------------------
-- 2. Schreibstil (ein versionierter Eintrag - Start-Zeile bleibt leer).
-- ----------------------------------------------------------------------------
create table mailassistent_schreibstil (
  id uuid primary key default gen_random_uuid(),
  inhalt text not null default '',
  version int not null default 1,
  immer_verfassen boolean not null default true,
  immer_antworten boolean not null default true,
  aktualisiert_am timestamptz not null default now(),
  aktualisiert_von text
);
insert into mailassistent_schreibstil default values;

-- ----------------------------------------------------------------------------
-- 3. Firmendaten (ein Eintrag, komplett leer) + Mitarbeiterliste (leer,
-- Zeilen werden ueber "+ Mitarbeiter hinzufuegen" erfasst).
-- ----------------------------------------------------------------------------
create table mailassistent_firmendaten (
  id uuid primary key default gen_random_uuid(),
  name_kunden text,
  name_rechnungen text,
  adresse text,
  telefon text,
  mobile text,
  web text,
  mwst_nummer text,
  bank text,
  iban text,
  swift_bic text,
  immer_verfassen boolean not null default true,
  immer_antworten boolean not null default true,
  aktualisiert_am timestamptz not null default now(),
  aktualisiert_von text
);
insert into mailassistent_firmendaten default values;

create table mailassistent_mitarbeiter (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  funktion text,
  reihenfolge int not null default 0
);

-- ----------------------------------------------------------------------------
-- 4. Mail-Vorlagen (Verfassen + Antworten, zunaechst leer). typ='rueckfrage'
-- Eintraege haben eine frage + mehrere Zweige in mailassistent_vorlage_antwort
-- statt eines einzelnen inhalt-Texts.
-- ----------------------------------------------------------------------------
create table mailassistent_vorlage (
  id uuid primary key default gen_random_uuid(),
  richtung text not null check (richtung in ('verfassen','antworten')),
  titel text not null,
  typ text not null default 'einfach' check (typ in ('einfach','rueckfrage')),
  inhalt text,
  frage text,
  wann_trifft_zu text,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now(),
  aktualisiert_am timestamptz not null default now()
);

create table mailassistent_vorlage_antwort (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references mailassistent_vorlage(id) on delete cascade,
  label text not null,
  inhalt text not null,
  reihenfolge int not null default 0
);

-- ----------------------------------------------------------------------------
-- 5. Sonderfaelle (leer, inkl. Ausnahme-Verknuepfung + Auffangfall-Flag als
-- Struktur - der eigentliche Auffangfall-Eintrag wird von euch selbst erstellt).
-- ----------------------------------------------------------------------------
create table mailassistent_sonderfall (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  stichwoerter text,
  verhalten text,
  ist_ausnahme_von uuid references mailassistent_sonderfall(id),
  ist_auffangfall boolean not null default false,
  immer_verfassen boolean not null default false,
  immer_antworten boolean not null default true,
  reihenfolge int not null default 0
);

-- ----------------------------------------------------------------------------
-- 6. Distanzlogik: Projekttypen (leer), Stufen (leer), Partnerbetriebe (leer),
-- gemeinsame Einstellungen (Start-Zeile leer, Umkreis-Schwelle mit sinnvollem
-- technischen Default - kein inhaltlicher Vorgaben-Text).
-- ----------------------------------------------------------------------------
create table mailassistent_distanz_projekttyp (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  beschreibung text,
  reihenfolge int not null default 0
);

create table mailassistent_distanz_stufe (
  id uuid primary key default gen_random_uuid(),
  projekttyp_id uuid not null references mailassistent_distanz_projekttyp(id) on delete cascade,
  bis_minuten int,
  vorlage_text text not null,
  ist_partner_logik boolean not null default false,
  reihenfolge int not null default 0
);

create table mailassistent_partnerbetrieb (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null,
  geprueft_ok boolean,
  geprueft_fehler text,
  geprueft_am timestamptz,
  reihenfolge int not null default 0
);

create table mailassistent_distanzlogik_meta (
  id uuid primary key default gen_random_uuid(),
  wann_anwenden text not null default '',
  partner_umkreis_minuten int not null default 35
);
insert into mailassistent_distanzlogik_meta default values;

-- ----------------------------------------------------------------------------
-- 7. Nachbessern-Buttons (leer, werden ueber "+ Neuen Button erstellen"
-- erfasst).
-- ----------------------------------------------------------------------------
create table mailassistent_nachbessern_button (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  anweisung text not null,
  reihenfolge int not null default 0
);

-- ----------------------------------------------------------------------------
-- 8. Einstellungen (technischer Default fuers Modell, keine Vorgaben-Inhalte)
-- + Nutzungs-Log (leer, wird nur von der Edge Function befuellt).
-- ----------------------------------------------------------------------------
create table mailassistent_einstellungen (
  id uuid primary key default gen_random_uuid(),
  anthropic_modell text not null default 'claude-sonnet-5'
);
insert into mailassistent_einstellungen default values;

create table mailassistent_nutzung_log (
  id uuid primary key default gen_random_uuid(),
  mitarbeiter_email text not null,
  richtung text check (richtung in ('verfassen','antworten')),
  vorlage_id uuid references mailassistent_vorlage(id),
  tokens_input int not null default 0,
  tokens_output int not null default 0,
  erstellt_am timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 9. RLS: alle mailassistent_* Tabellen nur fuer Buero-Team/Admin lesbar UND
-- schreibbar (kein abgestuftes Lese-vs-Schreib-Recht wie bei Tool B/C - siehe
-- ist_buero_oder_admin() oben).
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'mailassistent_schreibstil','mailassistent_firmendaten','mailassistent_mitarbeiter',
    'mailassistent_vorlage','mailassistent_vorlage_antwort','mailassistent_sonderfall',
    'mailassistent_distanz_projekttyp','mailassistent_distanz_stufe','mailassistent_partnerbetrieb',
    'mailassistent_distanzlogik_meta','mailassistent_nachbessern_button',
    'mailassistent_einstellungen','mailassistent_nutzung_log'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_buero_admin on %I for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());', t, t);
  end loop;
end $$;
