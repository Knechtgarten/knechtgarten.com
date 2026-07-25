-- ============================================================================
-- Offertentool 2027 - Offerten-Positionen: Einheit + Rundung konfigurierbar
--
-- Die Berechnungslogik selbst (wie Personal-/Materialaufwand aggregiert
-- werden) bleibt fest im Code (tool-a-live-v1.html, recalc()). Nur die
-- Anzeige-Einheit und die Rundungsregel fuer Menge/Preis sollen ohne
-- Code-Aenderung anpassbar sein - deshalb hier ausgelagert statt im Code
-- hartcodiert. Gilt aktuell bewusst NUR fuer Offerte-Typ "Formel" (siehe
-- Formel-Only-Guards in recalc()); fuer "Tagessatz" (Allgemein) bleibt das
-- bisherige, fest im Code stehende Verhalten unveraendert.
--
-- schluessel bindet die Zeile an eine im Code fest benannte Kategorie
-- ('personalaufwand', 'materialaufwand', 'maschinenaufwand') - Name/Erklaerung dazu bleiben in
-- einstellungen-live-v1.html (TEILFLAECHENLOGIK_KATALOG) hartcodiert.
-- rundung_menge/rundung_preis sind eines von: 'ganze_zahl', '1_dezimal',
-- '2_dezimal', 'auf_500', 'auf_5000' (siehe RUNDUNGSREGEL_FN in tool-a-live-v1.html).
-- ============================================================================

create table offerten_position_einstellung (
  schluessel text primary key,
  einheit text not null,
  rundung_menge text not null default 'ganze_zahl',
  rundung_preis text not null default '1_dezimal'
);

insert into offerten_position_einstellung (schluessel, einheit, rundung_menge, rundung_preis) values
  ('personalaufwand', 'Std', 'ganze_zahl', '1_dezimal'),
  ('materialaufwand', 'Stk', 'ganze_zahl', '1_dezimal'),
  ('maschinenaufwand', 'Budg.', 'ganze_zahl', '1_dezimal');

alter table offerten_position_einstellung enable row level security;
create policy offerten_position_einstellung_lesen on offerten_position_einstellung for select using (ist_eingeloggter_benutzer());
create policy offerten_position_einstellung_admin_schreibt on offerten_position_einstellung for all using (ist_admin()) with check (ist_admin());
