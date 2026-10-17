-- ============================================================================
-- Pflege- und Service-Tool (Dauerpflege-Kunden) - Etappe 1: ganzes Datenmodell
--
-- Gleiches Supabase-Projekt wie das Offertentool, Tabellen mit Praefix
-- pflege_ (wie mailassistent_*, dokumentensuche_*). Kunden kommen aus der
-- bestehenden Tabelle kunde (Easybill-Verknuepfung), Einheiten aus der
-- zentralen Tabelle einheit. Vorlage: docs/pflegetool/pflegetool-mockup-v56.html
--
-- Rechte:
--   Einstellungen (Kategorien, Felder, Standardarbeiten, Tabelle, Mitarbeiter):
--     lesen = alle eingeloggten, schreiben = Buero-Team/Admin
--   Kundendaten (Werte, Arbeiten, Status, Fotos, Dokumente):
--     alle eingeloggten (Techniker duerfen Angaben/Fotos/Status ergaenzen)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Einheiten: zentrale Tabelle wiederverwenden, Auswahl fuers Pflege-Tool per Flag
-- ----------------------------------------------------------------------------
alter table einheit add column if not exists im_pflegetool boolean not null default false;
insert into einheit (code, name) values ('%', 'Prozent') on conflict (code) do nothing;
update einheit set im_pflegetool = true where code in ('m²', 'm³', 'm', 'Stk.', 'Std.', '%');

-- ----------------------------------------------------------------------------
-- Pflegekategorien + Definitionen
-- ----------------------------------------------------------------------------
create table pflege_kategorie (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  kuerzel text not null check (char_length(kuerzel) between 1 and 3),
  farbe text not null default '#8B9097',
  reihenfolge integer not null default 0,
  individuell boolean not null default false, -- keine festen Felder/Standardarbeiten (z.B. «Individuell»)
  erstellt_am timestamptz not null default now()
);

-- Angaben / Eckdaten pro Kategorie
create table pflege_feld (
  id uuid primary key default gen_random_uuid(),
  kategorie_id uuid not null references pflege_kategorie(id) on delete cascade,
  name text not null,
  typ text not null check (typ in ('zahl', 'text', 'notiz', 'janein', 'auswahl')),
  einheit text null,                          -- nur bei typ 'zahl', Code aus einheit
  optionen jsonb not null default '[]'::jsonb, -- nur bei 'auswahl'; bleibt bei Typwechsel erhalten
  reihenfolge integer not null default 0
);
create index pflege_feld_kategorie_idx on pflege_feld (kategorie_id, reihenfolge);

-- Standardarbeiten pro Kategorie
create table pflege_arbeit (
  id uuid primary key default gen_random_uuid(),
  kategorie_id uuid not null references pflege_kategorie(id) on delete cascade,
  name text not null,
  standard_kw integer null check (standard_kw between 1 and 53),
  ablauf text null,                           -- ein Punkt pro Zeile
  reihenfolge integer not null default 0
);
create index pflege_arbeit_kategorie_idx on pflege_arbeit (kategorie_id, reihenfolge);

-- Hoechstens eine Tabelle pro Kategorie (z.B. Bewaesserungsplan)
create table pflege_tabelle (
  id uuid primary key default gen_random_uuid(),
  kategorie_id uuid not null unique references pflege_kategorie(id) on delete cascade,
  name text not null
);

create table pflege_tabelle_spalte (
  id uuid primary key default gen_random_uuid(),
  tabelle_id uuid not null references pflege_tabelle(id) on delete cascade,
  name text not null,
  typ text not null check (typ in ('text', 'zahl', 'zeitspanne', 'uhrzeit', 'janein', 'auswahl')),
  einheit text null,
  optionen jsonb not null default '[]'::jsonb,
  reihenfolge integer not null default 0
);
create index pflege_tabelle_spalte_tabelle_idx on pflege_tabelle_spalte (tabelle_id, reihenfolge);

-- ----------------------------------------------------------------------------
-- Service-Mitarbeiter (Feld «Zustaendig») - eigene Liste, Login optional
-- ----------------------------------------------------------------------------
create table pflege_mitarbeiter (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  aktiv boolean not null default true,
  benutzer_id uuid null unique references benutzer(id) on delete set null,
  reihenfolge integer not null default 0
);

-- ----------------------------------------------------------------------------
-- Kundendaten
-- ----------------------------------------------------------------------------
-- Pflege-Angaben pro Kunde (Kunde selbst = Tabelle kunde, nicht duplizieren)
create table pflege_kunde (
  kunde_id uuid primary key references kunde(id) on delete restrict,
  abo_typ text not null default 'kein_abo'
    check (abo_typ in ('ohne_voranmeldung', 'mit_voranmeldung', 'kein_abo')),
  notiz text null,
  erstellt_am timestamptz not null default now(),
  aktualisiert_am timestamptz not null default now()
);

-- Kunde <-> Kategorie (Register beim Kunden)
--   werte: {"<feld_id>": wert, ...}
--   tabelle_zeilen: [{"<spalte_id>": wert, ...}, ...] - per Spalten-ID, damit
--   Verschieben von Spalten nichts umschreiben muss
create table pflege_kunde_kategorie (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references pflege_kunde(kunde_id) on delete cascade,
  kategorie_id uuid not null references pflege_kategorie(id) on delete restrict,
  werte jsonb not null default '{}'::jsonb,
  tabelle_zeilen jsonb not null default '[]'::jsonb,
  erstellt_am timestamptz not null default now(),
  unique (kunde_id, kategorie_id)
);
create index pflege_kunde_kategorie_kategorie_idx on pflege_kunde_kategorie (kategorie_id);

-- Zustaendig: 0..n Mitarbeiter pro Kunde+Kategorie
create table pflege_kunde_kategorie_zustaendig (
  kunde_kategorie_id uuid not null references pflege_kunde_kategorie(id) on delete cascade,
  mitarbeiter_id uuid not null references pflege_mitarbeiter(id) on delete cascade,
  primary key (kunde_kategorie_id, mitarbeiter_id)
);

-- Arbeiten beim Kunden: Standardarbeit (arbeit_id gesetzt) oder Zusatzarbeit (titel)
--   kw null = Standard-KW der Arbeit; abgewaehlte_jahre = Jahre, in denen sie nicht gilt
create table pflege_kunde_arbeit (
  id uuid primary key default gen_random_uuid(),
  kunde_kategorie_id uuid not null references pflege_kunde_kategorie(id) on delete cascade,
  arbeit_id uuid null references pflege_arbeit(id) on delete cascade,
  titel text null,
  beschrieb text null,
  kw integer null check (kw between 1 and 53),
  abgewaehlte_jahre integer[] not null default '{}',
  erstellt_am timestamptz not null default now(),
  check (arbeit_id is not null or (titel is not null and kw is not null))
);
create unique index pflege_kunde_arbeit_standard_uniq on pflege_kunde_arbeit (kunde_kategorie_id, arbeit_id) where arbeit_id is not null;

-- Einsatz-Status pro Jahr + KW + Kunde + Kategorie (Zeile vorhanden = erledigt)
create table pflege_einsatz_status (
  kunde_kategorie_id uuid not null references pflege_kunde_kategorie(id) on delete cascade,
  jahr integer not null,
  kw integer not null check (kw between 1 and 53),
  erledigt_am timestamptz not null default now(),
  erledigt_von uuid null references benutzer(id) on delete set null,
  primary key (kunde_kategorie_id, jahr, kw)
);

-- Fotos gehoeren zum Kunden, 0..n Kategorien als Schlagwort
create table pflege_foto (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references pflege_kunde(kunde_id) on delete cascade,
  storage_pfad text not null,
  beschriftung text null,
  aufgenommen_am timestamptz not null default now(),
  erstellt_von uuid null references benutzer(id) on delete set null
);
create index pflege_foto_kunde_idx on pflege_foto (kunde_id);

create table pflege_foto_kategorie (
  foto_id uuid not null references pflege_foto(id) on delete cascade,
  kategorie_id uuid not null references pflege_kategorie(id) on delete cascade,
  primary key (foto_id, kategorie_id)
);

-- Angebote (aus Easybill verknuepft, PDF-Kopie) und allgemeine Dokumente (Upload)
create table pflege_dokument (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references pflege_kunde(kunde_id) on delete cascade,
  art text not null check (art in ('angebot', 'dokument')),
  titel text not null,
  datum date null,
  easybill_dokument_id bigint null,
  easybill_nummer text null,
  storage_pfad text null,
  ersetzt boolean not null default false,
  erstellt_am timestamptz not null default now()
);
create index pflege_dokument_kunde_idx on pflege_dokument (kunde_id);

create table pflege_dokument_kategorie (
  dokument_id uuid not null references pflege_dokument(id) on delete cascade,
  kategorie_id uuid not null references pflege_kategorie(id) on delete cascade,
  primary key (dokument_id, kategorie_id)
);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'pflege_kategorie', 'pflege_feld', 'pflege_arbeit', 'pflege_tabelle',
    'pflege_tabelle_spalte', 'pflege_mitarbeiter'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_lesen on %I for select using (ist_eingeloggter_benutzer());', t, t);
    execute format('create policy %I_buero_admin on %I for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());', t, t);
  end loop;

  foreach t in array array[
    'pflege_kunde', 'pflege_kunde_kategorie', 'pflege_kunde_kategorie_zustaendig',
    'pflege_kunde_arbeit', 'pflege_einsatz_status', 'pflege_foto', 'pflege_foto_kategorie',
    'pflege_dokument', 'pflege_dokument_kategorie'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_voller_zugriff on %I for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());', t, t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- Startdaten: Pflegekategorien aus dem Mockup (v56)
-- ----------------------------------------------------------------------------
do $$
declare
  k uuid;
  t uuid;
begin
  -- Gartenpflege
  insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge) values ('Gartenpflege', 'GP', '#D1DB5F', 1) returning id into k;
  insert into pflege_feld (kategorie_id, name, typ, einheit, optionen, reihenfolge) values
    (k, 'Rasenfläche', 'zahl', 'm²', '[]', 1),
    (k, 'Heckenlänge', 'zahl', 'm', '[]', 2),
    (k, 'Staudenflächen', 'zahl', 'm²', '[]', 3),
    (k, 'Grüngut', 'auswahl', null, '["Abführen", "Kompost vor Ort"]', 4);
  insert into pflege_arbeit (kategorie_id, name, standard_kw, reihenfolge) values
    (k, 'Frühlingspflege', 14, 1),
    (k, 'Sommerpflege', 25, 2),
    (k, 'Herbstpflege', 43, 3);

  -- Winterschnitt
  insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge) values ('Winterschnitt', 'WS', '#4C5C70', 2) returning id into k;
  insert into pflege_feld (kategorie_id, name, typ, einheit, optionen, reihenfolge) values
    (k, 'Obstbäume', 'zahl', 'Stk.', '[]', 1),
    (k, 'Ziergehölze', 'zahl', 'Stk.', '[]', 2),
    (k, 'Hecken', 'text', null, '[]', 3),
    (k, 'Hebebühne nötig', 'janein', null, '[]', 4);
  insert into pflege_arbeit (kategorie_id, name, standard_kw, reihenfolge) values
    (k, 'Obstbaumschnitt', 5, 1),
    (k, 'Gehölz- und Heckenschnitt', 8, 2);

  -- Bewaesserung
  insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge) values ('Bewässerung', 'BW', '#D6E7F4', 3) returning id into k;
  insert into pflege_feld (kategorie_id, name, typ, einheit, optionen, reihenfolge) values
    (k, 'Steuergerät', 'auswahl', null, '["Hunter Pro-HC", "Hunter X-Core", "Rain Bird ESP-TM2", "Gardena Smart"]', 1),
    (k, 'Anzahl Ventile', 'zahl', 'Stk.', '[]', 2),
    (k, 'Bewässerungsfläche', 'zahl', 'm²', '[]', 3),
    (k, 'Entleerung', 'auswahl', null, '["Druckluft ausblasen", "Entleerungsventil"]', 4),
    (k, 'Hauptabsperrung', 'text', null, '[]', 5),
    (k, 'Bemerkungen', 'notiz', null, '[]', 6);
  insert into pflege_arbeit (kategorie_id, name, standard_kw, ablauf, reihenfolge) values
    (k, 'Auswintern / Inbetriebnahme', 16,
     E'Hauptabsperrung öffnen, Leitungen langsam füllen\nEntleerungsventile schliessen\nSteuergerät einschalten, Datum und Uhrzeit prüfen\nBatterie im Steuergerät prüfen, bei Bedarf ersetzen\nJede Zone einzeln starten, Regner und Tropfer kontrollieren\nRegnerköpfe ausrichten, Düsen reinigen oder ersetzen\nRegensensor prüfen\nLaufzeiten auf Frühling einstellen\nMängel und Material notieren', 1),
    (k, 'Funktionskontrolle Sommer', 26, null, 2),
    (k, 'Einwintern / Ausblasen', 44,
     E'Steuergerät auf Winterbetrieb stellen (Bewässerung aus)\nHauptabsperrung schliessen\nKompressor anschliessen, Druck max. 3 bar\nZonen einzeln ausblasen, bis nur noch Luft kommt\nEntleerungsventile öffnen und offen lassen\nAussenhahn und Filter entleeren\nBatterie aus Funk-Steuergeräten entfernen\nAuffälligkeiten notieren', 3);
  insert into pflege_tabelle (kategorie_id, name) values (k, 'Bewässerungsplan') returning id into t;
  insert into pflege_tabelle_spalte (tabelle_id, name, typ, einheit, optionen, reihenfolge) values
    (t, 'Zeit', 'zeitspanne', null, '[]', 1),
    (t, 'Ventilname', 'text', null, '[]', 2),
    (t, 'Ventil-Nr.', 'zahl', null, '[]', 3),
    (t, 'Reagiert mit Sensor', 'janein', null, '[]', 4),
    (t, 'Intervall', 'auswahl', null, '["Täglich", "Alle 2 Tage", "Wöchentlich"]', 5),
    (t, 'Grenzwert', 'zahl', '%', '[]', 6);

  -- Poolservice
  insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge) values ('Poolservice', 'PS', '#323E4E', 4) returning id into k;
  insert into pflege_feld (kategorie_id, name, typ, einheit, optionen, reihenfolge) values
    (k, 'Beckenmasse (L × B × T)', 'text', null, '[]', 1),
    (k, 'Wasservolumen', 'zahl', 'm³', '[]', 2),
    (k, 'Steuerung / Dosierung', 'auswahl', null, '["Bayrol Analyt", "Dinotec Net-Dialog", "Pool-Commander", "Keine"]', 3),
    (k, 'Filteranlage', 'text', null, '[]', 4),
    (k, 'UVC-Entkeimung', 'janein', null, '[]', 5),
    (k, 'Abdeckung', 'auswahl', null, '["Rollladen", "Schiebedach", "Winterplane", "Keine"]', 6);
  insert into pflege_arbeit (kategorie_id, name, standard_kw, reihenfolge) values
    (k, 'Auswintern / Inbetriebnahme', 17, 1),
    (k, 'UVC-Lampe wechseln', 17, 2),
    (k, 'Sommerservice', 28, 3),
    (k, 'Einwintern', 41, 4);

  -- Schwimmteich
  insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge) values ('Schwimmteich', 'ST', '#6E9A8F', 5) returning id into k;
  insert into pflege_feld (kategorie_id, name, typ, einheit, optionen, reihenfolge) values
    (k, 'Wasserfläche', 'zahl', 'm²', '[]', 1),
    (k, 'Regenerationszone', 'zahl', 'm²', '[]', 2),
    (k, 'Pumpe', 'text', null, '[]', 3),
    (k, 'Skimmer', 'zahl', 'Stk.', '[]', 4);
  insert into pflege_arbeit (kategorie_id, name, standard_kw, reihenfolge) values
    (k, 'Frühjahrsreinigung', 15, 1),
    (k, 'Pflanzenrückschnitt', 41, 2);

  -- Individuell (keine festen Felder, Arbeiten direkt beim Kunden)
  insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge, individuell) values ('Individuell', 'IV', '#8B9097', 6, true);
end $$;
