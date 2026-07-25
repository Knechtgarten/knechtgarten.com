-- ============================================================================
-- Offertentool 2027 - Kies-/Beton-Transport: Kieswerke mit Kilometerpreis
-- statt PLZ-Zonen.
--
-- Ersetzt die bisherige PLZ-Zonen-Loesung (zonengruppe "Kiestransport"/
-- "Betontransport") durch eine Kieswerk-Tabelle mit Pauschale + Kilometerpreis,
-- getrennt fuer Kies und Beton. Die Fahrdistanz Kieswerk -> Kunde wird in
-- Tool A spaeter ueber die bestehende Distance-Matrix-Anbindung berechnet
-- (wie bei der Lieferwagenfahrzeit) - welches Kieswerk verwendet wird, waehlt
-- der Mitarbeiter pro Offerte manuell aus.
-- ============================================================================

create table kieswerk (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null default '',
  pauschale_kies numeric not null default 0,
  km_preis_kies numeric not null default 0,
  pauschale_beton numeric not null default 0,
  km_preis_beton numeric not null default 0,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now()
);

alter table kieswerk enable row level security;
create policy kieswerk_lesen on kieswerk for select using (ist_eingeloggter_benutzer());
create policy kieswerk_admin_schreibt on kieswerk for all using (ist_admin()) with check (ist_admin());

-- Alte PLZ-Zonen-Loesung entfernen. Falls eine bestehende Ressourcenzeile in
-- Tool B noch auf "Kiestransport" oder "Betontransport" verweist, schlaegt
-- dies kontrolliert fehl (on delete restrict) - dann zuerst die betroffene
-- Ressourcenzeile in Tool B entfernen und die Migration erneut ausfuehren.
delete from zonengruppe where name in ('Kiestransport', 'Betontransport');
