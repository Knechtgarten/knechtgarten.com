-- ============================================================================
-- Dokumenten-Suche: URL-Zuordnung fuer automatische Tab-Auswahl.
--
-- Die Erweiterung zeigt jetzt Tabs (Alle/Drive/Gmail/PEAX) statt einer
-- gemeinsamen Quelle-Mehrfachauswahl. Beim Oeffnen des Seitenpanels soll
-- automatisch der passende Tab vorausgewaehlt sein, je nachdem welche
-- Webseite im aktiven Browser-Tab gerade offen ist (z.B. drive.google.com
-- -> Drive-Tab). Fest im Erweiterungscode hinterlegt sind nur die
-- offensichtlichen Standardfaelle (Drive/Gmail/PEAX selbst) - diese Tabelle
-- erlaubt zusaetzliche, admin-pflegbare Zuordnungen (z.B. easybill.de ->
-- Drive) sowie einen konfigurierbaren Fallback fuer nicht zugeordnete
-- Seiten (liegt in dokumentensuche_einstellungen.standard_tab_fallback).
-- ============================================================================

create table dokumentensuche_url_zuordnung (
  id uuid primary key default gen_random_uuid(),
  url_muster text not null,
  standard_tab text not null check (standard_tab in ('alle', 'drive', 'gmail', 'peax')),
  sortierung int not null default 0,
  aktiv boolean not null default true,
  erstellt_am timestamptz not null default now()
);

alter table dokumentensuche_einstellungen
  add column standard_tab_fallback text not null default 'alle'
    check (standard_tab_fallback in ('alle', 'drive', 'gmail', 'peax'));

alter table dokumentensuche_url_zuordnung enable row level security;
create policy dokumentensuche_url_zuordnung_buero_admin on dokumentensuche_url_zuordnung
  for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
