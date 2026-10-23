-- ============================================================================
-- Wissen & Geräte, Etappe 1: Grundstruktur
--
-- wissen_kategorie         Was ist es? (Maschinen & Fahrzeuge, Kleber ...) - genau 1 pro Eintrag
-- wissen_bereich           Wer braucht es? (Büro & Planung, Baustelle ...) - mehrere pro Eintrag
-- wissen_eintrag           Gerät, Produkt oder Wissen. Steckbrief/Verwaltung als
--                          Liste [{label, wert}], Anwendung als HTML (Textfeld wie Tool A).
--                          qr_nr = kurze, feste Nummer fuer den QR-Code (knechtgarten.com/g/<qr_nr>).
--                          planer_ressource_id = «im Planer verwendet» (Bagger, Lieferwagen ...).
--                          gehoert_zu_id = Anbaugeraet gehoert zu Bagger X.
-- wissen_notiz             mehrere Notizen pro Eintrag (HTML), mit Datum und Verfasser
-- wissen_kontakt           Lieferant (Lieferantenliste), Kunde (Easybill-Kopie) oder frei
-- wissen_datei             Fotos, Videos, PDF. bereich: titel / anwendung / notiz / dokument.
--                          auch_bei = gleiche Datei (z.B. Sammelrechnung) bei weiteren Eintraegen
-- wissen_service           Service-Arbeit: entweder Standard fuer eine Geraeteart
--                          (geraeteart gesetzt) oder Zusatzarbeit fuer einen Eintrag (eintrag_id)
-- wissen_service_abw       Abweichung vom Standard pro Eintrag (zusaetzliche / weggelassene KW)
-- wissen_service_erledigt  «Erledigt» pro Arbeit, Jahr und KW (Datum, Zaehlerstand, Rechnung)
--
-- Rechte: lesen alle Eingeloggten. Eintraege, Kategorien, Service-Plan: Admin + Buero.
-- Notizen, Dateien, Kontakte, Erledigt: alle Eingeloggten (Mitarbeitende ergaenzen vor Ort).
-- ============================================================================

create table wissen_kategorie (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sortierung int not null default 0
);

create table wissen_bereich (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sortierung int not null default 0
);

create sequence wissen_qr_nr_seq start 1;

create table wissen_eintrag (
  id uuid primary key default gen_random_uuid(),
  qr_nr int not null unique default nextval('wissen_qr_nr_seq'),
  typ text not null default 'geraet' check (typ in ('geraet', 'produkt', 'wissen')),
  titel text not null,
  untertitel text null,
  nummer text null,                        -- Bagger-Nr., Kontrollschild ...
  kategorie_id uuid null references wissen_kategorie(id) on delete set null,
  bereich_ids uuid[] not null default '{}',
  tags text[] not null default '{}',
  geraeteart text null,                    -- «Raupenbagger», «Lieferwagen» - Service-Standard gilt pro Geraeteart
  zustaendig text null,
  steckbrief jsonb not null default '[]',  -- [{"label": "Gewicht", "wert": "9 t"}]
  verwaltung jsonb not null default '[]',  -- nur Buero, nicht beim QR-Scan
  anwendung_html text null,
  gehoert_zu_id uuid null references wissen_eintrag(id) on delete set null,
  planer_ressource_id uuid null unique references planer_ressource(id) on delete set null,
  titelfoto_pfad text null,
  geprueft_am date null,
  geprueft_von uuid null references benutzer(id) on delete set null on update cascade,
  archiviert_am timestamptz null,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create index wissen_eintrag_kategorie_idx on wissen_eintrag (kategorie_id);
create index wissen_eintrag_gehoert_idx on wissen_eintrag (gehoert_zu_id);

create table wissen_notiz (
  id uuid primary key default gen_random_uuid(),
  eintrag_id uuid not null references wissen_eintrag(id) on delete cascade,
  html text not null default '',
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create index wissen_notiz_eintrag_idx on wissen_notiz (eintrag_id);

create table wissen_kontakt (
  id uuid primary key default gen_random_uuid(),
  eintrag_id uuid not null references wissen_eintrag(id) on delete cascade,
  art text not null check (art in ('lieferant', 'kunde', 'frei')),
  lieferant_id uuid null references lieferant(id) on delete cascade,
  kunde_id uuid null references kunde(id) on delete cascade,
  name text null,                          -- bei «frei»: z.B. Werkstatt, Metallbauer
  rolle text null,                         -- «Händler / Ersatzteile», «Werkstatt», «Eingesetzt bei»
  sortierung int not null default 0,
  erstellt_am timestamptz not null default now(),
  check ((art = 'lieferant' and lieferant_id is not null) or (art = 'kunde' and kunde_id is not null) or (art = 'frei' and name is not null))
);
create index wissen_kontakt_eintrag_idx on wissen_kontakt (eintrag_id);

create table wissen_datei (
  id uuid primary key default gen_random_uuid(),
  eintrag_id uuid not null references wissen_eintrag(id) on delete cascade,
  notiz_id uuid null references wissen_notiz(id) on delete cascade,
  bereich text not null default 'dokument' check (bereich in ('anwendung', 'notiz', 'dokument')),
  art text not null check (art in ('foto', 'video', 'pdf', 'datei')),
  name text not null,
  beschreibung text null,
  storage_pfad text not null,
  vorschau_pfad text null,
  groesse bigint null,
  auch_bei uuid[] not null default '{}',
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);
create index wissen_datei_eintrag_idx on wissen_datei (eintrag_id);
create index wissen_datei_auch_bei_idx on wissen_datei using gin (auch_bei);

create table wissen_service (
  id uuid primary key default gen_random_uuid(),
  eintrag_id uuid null references wissen_eintrag(id) on delete cascade,
  geraeteart text null,
  arbeit text not null,
  kws int[] not null default '{}',
  zeit text null,                          -- «½ Tag», «1 Std.»
  wer text null,                           -- «Werkstatt», «intern»
  sortierung int not null default 0,
  erstellt_am timestamptz not null default now(),
  check ((eintrag_id is null) <> (geraeteart is null))
);
create index wissen_service_eintrag_idx on wissen_service (eintrag_id);
create index wissen_service_art_idx on wissen_service (geraeteart);

create table wissen_service_abw (
  eintrag_id uuid not null references wissen_eintrag(id) on delete cascade,
  service_id uuid not null references wissen_service(id) on delete cascade,
  kws_plus int[] not null default '{}',
  kws_minus int[] not null default '{}',
  primary key (eintrag_id, service_id)
);

create table wissen_service_erledigt (
  id uuid primary key default gen_random_uuid(),
  eintrag_id uuid not null references wissen_eintrag(id) on delete cascade,
  service_id uuid null references wissen_service(id) on delete set null,
  arbeit text not null,                    -- Name zum Zeitpunkt (bleibt, auch wenn Arbeit geloescht wird)
  jahr int not null,
  kw int not null check (kw between 1 and 53),
  erledigt boolean not null default true,  -- false = bewusst nicht gemacht (z.B. «kein Service 2024»)
  datum date null,
  stand text null,                         -- km / Betriebsstunden
  bemerkung text null,
  datei_id uuid null references wissen_datei(id) on delete set null,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);
create index wissen_service_erledigt_eintrag_idx on wissen_service_erledigt (eintrag_id);

create or replace function wissen_touch()
returns trigger language plpgsql as $$
begin new.geaendert_am := now(); return new; end; $$;
create trigger wissen_eintrag_touch before update on wissen_eintrag for each row execute function wissen_touch();
create trigger wissen_notiz_touch before update on wissen_notiz for each row execute function wissen_touch();

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
alter table wissen_kategorie enable row level security;
alter table wissen_bereich enable row level security;
alter table wissen_eintrag enable row level security;
alter table wissen_notiz enable row level security;
alter table wissen_kontakt enable row level security;
alter table wissen_datei enable row level security;
alter table wissen_service enable row level security;
alter table wissen_service_abw enable row level security;
alter table wissen_service_erledigt enable row level security;

create policy wissen_kategorie_lesen on wissen_kategorie for select using (ist_eingeloggter_benutzer());
create policy wissen_kategorie_buero on wissen_kategorie for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy wissen_bereich_lesen on wissen_bereich for select using (ist_eingeloggter_benutzer());
create policy wissen_bereich_buero on wissen_bereich for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy wissen_eintrag_lesen on wissen_eintrag for select using (ist_eingeloggter_benutzer());
create policy wissen_eintrag_buero on wissen_eintrag for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy wissen_service_lesen on wissen_service for select using (ist_eingeloggter_benutzer());
create policy wissen_service_buero on wissen_service for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy wissen_service_abw_lesen on wissen_service_abw for select using (ist_eingeloggter_benutzer());
create policy wissen_service_abw_buero on wissen_service_abw for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

create policy wissen_notiz_alle on wissen_notiz for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy wissen_kontakt_alle on wissen_kontakt for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy wissen_datei_alle on wissen_datei for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy wissen_erledigt_alle on wissen_service_erledigt for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- ----------------------------------------------------------------------------
-- Speicher (privat, Anzeige ueber signierte Links). Pfad: <eintrag_id>/<datei_id>.<ext>
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('wissen-dateien', 'wissen-dateien', false, 52428800,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4', 'video/quicktime', 'video/webm'])
on conflict (id) do nothing;

create policy "wissen-dateien lesen" on storage.objects
  for select using (bucket_id = 'wissen-dateien' and ist_eingeloggter_benutzer());
create policy "wissen-dateien hochladen" on storage.objects
  for insert with check (bucket_id = 'wissen-dateien' and ist_eingeloggter_benutzer());
create policy "wissen-dateien loeschen" on storage.objects
  for delete using (bucket_id = 'wissen-dateien' and ist_eingeloggter_benutzer());

-- ----------------------------------------------------------------------------
-- Startwerte
-- ----------------------------------------------------------------------------
insert into wissen_kategorie (name, sortierung) values
  ('Maschinen & Fahrzeuge', 10), ('Geräte & Werkzeug', 20), ('Kleber & Dichtstoffe', 30),
  ('Chemikalien', 40), ('Metall & Befestigung', 50), ('Pooltechnik', 60), ('Bewässerung', 70),
  ('Pflanzen', 80), ('Dünger & Substrate', 90), ('Software & Büro', 100);

insert into wissen_bereich (name, sortierung) values
  ('Büro & Planung', 10), ('Baustelle', 20), ('Pflege', 30), ('Poolbau & Wasser', 40), ('Werkstatt & Fuhrpark', 50);

-- Kachel auf der Startseite (alle Rollen: Mitarbeitende scannen QR-Codes auf den Maschinen)
insert into modul_sichtbarkeit (modul_key, name, kurzname, titel_mittel, text_gross, icon_key, hintergrund, fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values ('wissen', 'Wissen & Geräte', 'Wissen', 'Wissen & Geräte', 'Maschinen, Geräte, Produkte und Know-how nachschlagen.', 'wissen', 'blau', true, true, true)
on conflict (modul_key) do nothing;
