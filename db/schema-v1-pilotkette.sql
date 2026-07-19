-- ============================================================================
-- Offertentool 2027 - Datenbank-Schema, Entwurf v1
-- Scope: NUR die erste durchgaengige Pilot-Kette
--   Artikelstamm (Tool C) + Arbeitsschritt "Aushub" (Tool B) + Tool A rechnet damit
-- NICHT enthalten (bewusst spaeter): Tagessatz-Modell (Offertentyp "Allgemein"),
--   Zonen-Staffel/Mengen-Staffel-Tabellen, Datenabgleich/Sync-Automatisierung,
--   Benutzerrechte/Row-Level-Security, Easybill-Push.
-- Noch nicht gegen die echte Supabase-DB ausgefuehrt - erst Review durch Stefan.
-- ============================================================================

create extension if not exists "pgcrypto"; -- fuer gen_random_uuid()

-- ----------------------------------------------------------------------------
-- 1. OFFERTENTYP
-- Zentrale Liste (Pool/Wasseranlagen, Holzdeck, Allgemein, ...).
-- berechnungsmodell steuert in Tool A, welcher Bildschirm-Typ angezeigt wird.
-- ----------------------------------------------------------------------------
create table offertentyp (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  berechnungsmodell text not null check (berechnungsmodell in ('formel','tagessatz')),
  reihenfolge int not null default 0,
  ausgeblendet boolean not null default false,
  erstellt_am timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 2 + 3 + 4. FORMEL-BIBLIOTHEK
-- Eingabefelder = Blaetter (rohe Masse, z.B. Poollaenge).
-- Term = Knoten (Formel ODER Konstante), kann andere Terms/Eingabefelder referenzieren.
-- ausdruck ist ein verschachtelter JSON-Ausdrucksbaum, z.B.:
--   {"op":"*","args":[
--     {"ref":"eingabefeld","id":"<uuid Poollaenge>"},
--     {"ref":"eingabefeld","id":"<uuid Poolbreite>"},
--     {"op":"+","args":[
--       {"ref":"eingabefeld","id":"<uuid Beckentiefe>"},
--       {"ref":"term","id":"<uuid Auflockerungsfaktor>"}
--     ]}
--   ]}
-- Das ist die technische Umsetzung von "Terms werden per Name referenziert,
-- in der Ressourcen-Zeile nur ausgewaehlt und mit +/-/x/ueber kombiniert".
-- offertentyp_id = null bedeutet "Allgemein" (typuebergreifend).
-- ----------------------------------------------------------------------------
create table eingabefeld (
  id uuid primary key default gen_random_uuid(),
  offertentyp_id uuid null references offertentyp(id) on delete restrict,
  name text not null,
  einheit text not null,
  erklaerung text null,
  notiz text null,
  erstellt_am timestamptz not null default now(),
  unique (offertentyp_id, name)
);

create table term (
  id uuid primary key default gen_random_uuid(),
  offertentyp_id uuid null references offertentyp(id) on delete restrict,
  name text not null,
  typ text not null check (typ in ('formel','konstante')),
  wert numeric null,               -- nur bei typ='konstante'
  ausdruck jsonb null,             -- nur bei typ='formel'
  einheit text null,
  erklaerung text null,
  notiz text null,
  erstellt_am timestamptz not null default now(),
  unique (offertentyp_id, name),
  check (
    (typ = 'konstante' and wert is not null and ausdruck is null) or
    (typ = 'formel' and ausdruck is not null and wert is null)
  )
);

-- Abhaengigkeits-Tabelle: wird beim Anlegen/Aendern einer Formel aus dem
-- ausdruck-Baum abgeleitet und hier gespiegelt gespeichert. Zweck:
--   a) Loeschschutz -> die FK-Constraints unten (on delete restrict) verhindern
--      automatisch das Loeschen eines Eingabefelds/Terms, der noch referenziert wird.
--   b) UI-Abfrage "welche Formeln verwenden X" ist so ein einfacher Select,
--      statt bei jeder Anzeige den ganzen JSON-Baum aller Formeln zu durchsuchen.
create table term_abhaengigkeit (
  term_id uuid not null references term(id) on delete cascade,
  referenziertes_eingabefeld_id uuid null references eingabefeld(id) on delete restrict,
  referenzierter_term_id uuid null references term(id) on delete restrict,
  check (
    (referenziertes_eingabefeld_id is not null and referenzierter_term_id is null) or
    (referenziertes_eingabefeld_id is null and referenzierter_term_id is not null)
  ),
  unique (term_id, referenziertes_eingabefeld_id, referenzierter_term_id)
);

-- ----------------------------------------------------------------------------
-- 5-9. DATENMODELL-HIERARCHIE (Tool B)
-- Arbeitsschritt -> Teilschritt -> Auswahlfeld -> Auswahloption -> Ressourcenzeile
-- ----------------------------------------------------------------------------
create table arbeitsschritt (
  id uuid primary key default gen_random_uuid(),
  offertentyp_id uuid not null references offertentyp(id) on delete restrict,
  name text not null,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now()
);

create table teilschritt (
  id uuid primary key default gen_random_uuid(),
  arbeitsschritt_id uuid not null references arbeitsschritt(id) on delete cascade,
  name text not null,
  beschreibung text null,   -- Standardtext, siehe Memory offertentool-beschreibungen
  reihenfolge int not null default 0
);

create table auswahlfeld (
  id uuid primary key default gen_random_uuid(),
  teilschritt_id uuid not null references teilschritt(id) on delete cascade,
  name text not null,
  mehrfachauswahl boolean not null default false,
  reihenfolge int not null default 0
);

create table auswahloption (
  id uuid primary key default gen_random_uuid(),
  auswahlfeld_id uuid not null references auswahlfeld(id) on delete cascade,
  name text not null,
  reihenfolge int not null default 0
);

-- Ressourcenzeile: haengt an einer Option, bringt Personal/Maschine/Logistik/
-- Material mit. menge_ausdruck hat dieselbe Baum-Struktur wie term.ausdruck.
-- geltungsbereich + teilflaechenlogik bilden die "3 Stufen"-Regel ab
-- (siehe Memory: Pro Teilflaeche / Einmal pro Bauteil / Einmal pro Offerte).
create table ressourcenzeile (
  id uuid primary key default gen_random_uuid(),
  option_id uuid not null references auswahloption(id) on delete cascade,
  kategorie text not null check (kategorie in ('personal','maschine','logistik','material')),
  artikel_id uuid null,  -- FK folgt weiter unten (artikel-Tabelle kommt erst danach)
  bezeichnung_override text null,
  menge_ausdruck jsonb not null,
  preis_override numeric null,
  geltungsbereich text not null default 'teilflaeche'
    check (geltungsbereich in ('teilflaeche','bauteil','offerte')),
  teilflaechenlogik text not null default 'pro_teilflaeche'
    check (teilflaechenlogik in ('pro_teilflaeche','einmal_bauteil','gepoolt_runden')),
  notiz text null
);

-- ----------------------------------------------------------------------------
-- 10-12. ARTIKELSTAMM (Tool C)
-- ----------------------------------------------------------------------------
create table artikelgruppe (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table lieferant (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kuerzel text not null unique,
  sync_typ text not null default 'manuell'
    check (sync_typ in ('manuell','api','crawling','ftp_xml','google_sheet')),
  zoll_fracht_zuschlag_pct numeric not null default 0,
  sonderzuschlag_pct numeric not null default 0,
  minimum_marge_pct numeric not null default 0,
  mwst_satz_pct numeric not null default 8.1,
  preise_inkl_mwst boolean not null default false,
  waehrung_default text not null default 'CHF',
  -- Verbindungsdaten (API-Endpoint/Key, FTP-Zugang, Google-Sheet-Link usw.).
  -- WICHTIG (offene Pendenz, siehe Memory): Keys/Passwoerter muessen bei der
  -- echten Umsetzung verschluesselt gespeichert werden, hier erstmal nur
  -- strukturiert als jsonb angelegt, noch OHNE Verschluesselung.
  verbindungsdaten jsonb null,
  letzter_abgleich_status text null,
  letzter_abgleich_am timestamptz null,
  erstellt_am timestamptz not null default now()
);

create table artikel (
  id uuid primary key default gen_random_uuid(),
  lieferant_id uuid not null references lieferant(id) on delete restrict,
  artikelgruppe_id uuid null references artikelgruppe(id) on delete set null,
  kategorie text not null default 'material'
    check (kategorie in ('material','personal','maschine','logistik')),
  artikelnummer_lieferant text null,
  artikelnummer_knecht text null,  -- wird applikationsseitig aus kuerzel+artikelnummer_lieferant gebildet
  bezeichnung text not null,
  einheit text not null,
  ep_lieferant numeric null,
  vp_lieferant numeric null,
  waehrung text not null default 'CHF',
  wechselkurs numeric not null default 1,
  ep_lieferant_chf numeric null,
  vp_knecht numeric null,          -- manuell uebersteuerbar (Rundung, Aktion, Minimum-Marge)
  marge_aktuell_pct numeric null,
  mwst_satz_pct numeric null,      -- Override zum Lieferanten-Default, oft leer
  anmerkung text null,
  foto_url text null,
  shop_link text null,
  sync_offertentool boolean not null default true,
  sync_webtool boolean not null default false,
  sync_easybill boolean not null default false,
  easybill_id text null,
  erstellt_am timestamptz not null default now(),
  unique (lieferant_id, artikelnummer_lieferant)
);

alter table ressourcenzeile
  add constraint ressourcenzeile_artikel_fk
  foreign key (artikel_id) references artikel(id) on delete restrict;

-- ----------------------------------------------------------------------------
-- 13-17. KUNDE / OFFERTE / TEILFLAECHE (Tool A)
-- Eine Offerte = ein Offertentyp-Bauteil direkt (kein separates "Bauteil"
-- noetig, siehe Memory-Korrektur: die fruehere "Bauteile innerhalb einer
-- Offerte"-Idee wurde verworfen).
-- ----------------------------------------------------------------------------
create table kunde (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text null,
  kontakt jsonb null,
  erstellt_am timestamptz not null default now()
);

create table offerte (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references kunde(id) on delete cascade,
  offertentyp_id uuid not null references offertentyp(id) on delete restrict,
  titel text not null,
  datum date not null default current_date,
  status text not null default 'offen' check (status in ('offen','bestaetigt','abgelehnt')),
  notiz text null,
  erstellt_am timestamptz not null default now()
);

-- Nur relevant fuer Offertentypen mit berechnungsmodell='formel'.
create table teilflaeche (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  name text not null default 'Teilbereich',
  menge int not null default 1,
  zugaenglichkeitsfaktor numeric not null default 1,
  reihenfolge int not null default 0
);

create table teilflaeche_eingabefeld_wert (
  id uuid primary key default gen_random_uuid(),
  teilflaeche_id uuid not null references teilflaeche(id) on delete cascade,
  eingabefeld_id uuid not null references eingabefeld(id) on delete restrict,
  wert numeric not null,
  unique (teilflaeche_id, eingabefeld_id)
);

create table teilflaeche_auswahl (
  id uuid primary key default gen_random_uuid(),
  teilflaeche_id uuid not null references teilflaeche(id) on delete cascade,
  option_id uuid not null references auswahloption(id) on delete restrict,
  unique (teilflaeche_id, option_id)
);

-- ============================================================================
-- Bewusst NICHT in diesem Entwurf (kommt in spaeteren Etappen):
--  - Tagessatz-Modell-Tabellen fuer Offertentyp "Allgemein"
--  - Mengen-Staffel / Zonen-Staffel als eigene Term-Variante
--  - Row-Level-Security / Rollen (Benutzerrechte-Pendenz noch offen)
--  - Verschluesselung von lieferant.verbindungsdaten
--  - Easybill-Sync-Log, Offerten-Aggregate (zweistufige Berechnung)
-- ============================================================================
