-- ============================================================================
-- Dokumenten-Suche - Datenbank-Grundlage (nur Struktur, keine Rechercheinhalte).
--
-- Neues Tool auf der Tools-Seite (Kachel "Dokumenten-Suche" bereits in
-- app/tools-live-v1.html ergaenzt), analog zum Mail-Assistenten: eigene
-- Verwaltungsseite (app/dokumentensuche-verwaltung-live-v1.html), gleiche
-- Rollen-Sichtbarkeit (Buero-Team + Admin ueber ist_buero_oder_admin(),
-- siehe 20260906110000_mailassistent_schema.sql).
--
-- Zweck der Tabellen:
--  - dokumentensuche_dokumentart: die admin-pflegbare Liste der Dokumentarten
--    (Angebot/Rechnung/Lieferschein/...), die im Suchpanel als Filter-Chips
--    erscheinen (siehe Mockup "Suchpanel", Session 2026-09).
--  - dokumentensuche_einstellungen: globale Grundeinstellungen (Standard-
--    Suchgenauigkeit, ob Papierkorb/Spam standardmaessig mitdurchsucht wird).
--  - dokumentensuche_quelle_status: Verbindungsstatus pro Quelle (Drive/
--    Gmail/PEAX) - admin-sichtbar, damit klar ist, welche Quelle schon
--    angebunden ist (PEAX haengt an der noch offenen API-Kostenfrage).
--  - dokumentensuche_erweiterung_meta: Version/Download-Link der Browser-
--    Erweiterung, gleiches Verteil-Muster wie mailassistent_erweiterung_meta
--    (ZIP ueber Supabase Storage, kein Chrome-Web-Store-Zwang).
--  - dokumentensuche_nutzung_log: eine Zeile pro Suche (wer, wann, wonach),
--    fuer Nutzungs-/Kostenueberblick - analog mailassistent_nutzung_log.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Dokumentarten (Filter-Chips im Suchpanel: "Alle" ist rein UI-seitig,
-- kommt nicht aus dieser Tabelle).
-- ----------------------------------------------------------------------------
create table dokumentensuche_dokumentart (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sortierung int not null default 0,
  aktiv boolean not null default true,
  erstellt_am timestamptz not null default now()
);

insert into dokumentensuche_dokumentart (name, sortierung) values
  ('Angebot', 1),
  ('Rechnung', 2),
  ('Lieferschein', 3);

-- ----------------------------------------------------------------------------
-- 2. Globale Einstellungen (ein Eintrag, Start-Zeile bleibt mit Standardwerten
-- gefuellt statt leer - anders als beim Mail-Assistenten, weil hier konkrete
-- Defaults aus den Mockup-Entscheiden feststehen).
-- ----------------------------------------------------------------------------
create table dokumentensuche_einstellungen (
  id uuid primary key default gen_random_uuid(),
  such_genauigkeit_standard text not null default 'sinngemaess'
    check (such_genauigkeit_standard in ('genau','teilwort','sinngemaess')),
  papierkorb_spam_standard boolean not null default false,
  aktualisiert_am timestamptz not null default now(),
  aktualisiert_von text
);
insert into dokumentensuche_einstellungen default values;

-- ----------------------------------------------------------------------------
-- 3. Quelle-Status (Drive/Gmail/PEAX) - fixe drei Zeilen, keine weiteren
-- Quellen ueber die UI hinzufuegbar (Entscheid: Quellen sind Code, nicht Daten).
-- ----------------------------------------------------------------------------
create table dokumentensuche_quelle_status (
  quelle text primary key check (quelle in ('drive','gmail','peax')),
  aktiv boolean not null default false,
  status_text text,
  aktualisiert_am timestamptz not null default now()
);
insert into dokumentensuche_quelle_status (quelle, aktiv, status_text) values
  ('drive', false, 'Noch nicht eingerichtet'),
  ('gmail', false, 'Noch nicht eingerichtet'),
  ('peax',  false, 'API-Zugang bei PEAX angefragt, Antwort ausstehend');

-- ----------------------------------------------------------------------------
-- 4. Erweiterungs-Verteilung (ein Eintrag, analog mailassistent_erweiterung_meta).
-- ----------------------------------------------------------------------------
create table dokumentensuche_erweiterung_meta (
  id uuid primary key default gen_random_uuid(),
  version text,
  download_url text,
  aktualisiert_am timestamptz not null default now()
);
insert into dokumentensuche_erweiterung_meta default values;

-- ----------------------------------------------------------------------------
-- 5. Nutzungs-Log (eine Zeile pro Suche).
-- ----------------------------------------------------------------------------
create table dokumentensuche_nutzung_log (
  id uuid primary key default gen_random_uuid(),
  mitarbeiter_email text not null,
  suchbegriff text,
  quellen text[],
  erstellt_am timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 6. RLS: alle dokumentensuche_* Tabellen nur fuer Buero-Team/Admin lesbar UND
-- schreibbar (gleiche Regel wie beim Mail-Assistenten, ist_buero_oder_admin()
-- existiert bereits aus 20260906110000_mailassistent_schema.sql).
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'dokumentensuche_dokumentart','dokumentensuche_einstellungen',
    'dokumentensuche_quelle_status','dokumentensuche_erweiterung_meta',
    'dokumentensuche_nutzung_log'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_buero_admin on %I for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());', t, t);
  end loop;
end $$;
