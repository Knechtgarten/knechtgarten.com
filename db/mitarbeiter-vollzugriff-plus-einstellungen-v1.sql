-- ============================================================================
-- Offertentool 2027 - Mitarbeiter erhalten vollen Zugriff auf Tool B/C
-- (Arbeitsschritte, Artikelstamm), nicht mehr nur Lesen. Weiterhin Admin-only
-- bleiben: Formel-Bibliothek (eingabefeld/term/term_abhaengigkeit) und
-- Offertentyp-Verwaltung (offertentyp) - beide leben unter Einstellungen.
-- Ausserdem: neue, admin-only Tabellen fuer die Einstellungen-Rubrik
-- "Datenabgleich" (Lieferanten-Sync-Stammdaten, getrennt von der normalen
-- Lieferanten-Zeile in Tool C, die jetzt von Mitarbeitern editierbar ist).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Mitarbeiter: voller Zugriff statt nur Lesen
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'arbeitsschritt','teilschritt','auswahlfeld','auswahloption','ressourcenzeile',
    'artikelgruppe','lieferant','artikel'
  ] loop
    execute format('drop policy if exists %I_admin_schreibt on %I;', t, t);
    execute format('create policy %I_voller_zugriff on %I for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());', t, t);
  end loop;
end $$;
-- offertentyp, eingabefeld, term, term_abhaengigkeit bleiben unveraendert
-- (weiterhin admin-only schreibbar, siehe rls-und-rollen-v1.sql).

-- ----------------------------------------------------------------------------
-- 2. Datenabgleich: Lieferanten-Sync-Stammdaten, admin-only (eigene Tabelle,
--    weil die normale lieferant-Zeile selbst jetzt Mitarbeiter-editierbar ist -
--    Zoll/Fracht/Marge/Sync-Zugangsdaten sollen das nicht sein).
-- ----------------------------------------------------------------------------
create table lieferant_datenabgleich (
  lieferant_id uuid primary key references lieferant(id) on delete cascade,
  zoll_fracht_prozent numeric null,
  sonderzuschlag_prozent numeric null,
  minimum_marge_prozent numeric null,
  mwst_satz numeric null default 8.1,
  mwst_inklusive boolean not null default false,
  waehrung text not null default 'CHF',
  sync_verbindung jsonb null,          -- typ-spezifische Verbindungsdaten (Endpoint/Key, Host/Pfad/Benutzer, URL, Sheet-Link/Tabellenblatt)
  sync_erklaerung text null,           -- editierbares Freitextfeld "was passiert bei diesem Abgleich"
  letzter_abgleich_status text null,
  letzter_abgleich_zeitpunkt timestamptz null
);
alter table lieferant_datenabgleich enable row level security;
create policy lieferant_datenabgleich_admin on lieferant_datenabgleich for all using (ist_admin()) with check (ist_admin());

-- ----------------------------------------------------------------------------
-- 3. Wechselkurse: global, admin-only, unabhaengig von einzelnen Lieferanten.
-- ----------------------------------------------------------------------------
create table wechselkurs (
  id uuid primary key default gen_random_uuid(),
  waehrung text not null unique,
  kurs_zu_chf numeric not null,
  stand_vom date not null default current_date
);
alter table wechselkurs enable row level security;
create policy wechselkurs_admin on wechselkurs for all using (ist_admin()) with check (ist_admin());
