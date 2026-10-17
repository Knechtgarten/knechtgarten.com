-- ============================================================================
-- Offertentool 2027 - Belag-Dropdown, Etappe 2
--
-- 1) Dropdown-Spalten in Tabellen: der gewaehlte Eintrag (id des Belag-
--    Teilschritts) steht als Text beim Zellenwert, Zahlen bleiben in "wert".
-- 2) Zwei neue Systemwert-Keys fuer die Formelbausteine "Flaeche dieses
--    Belags" / "Flaeche aller Belaege" (Tool B legt die Terms automatisch an,
--    die Check-Constraint wuerde sie sonst stillschweigend ablehnen).
-- ============================================================================

alter table offerte_tabelle_wert add column if not exists text_wert text null;

alter table term drop constraint if exists term_systemwert_key_check;
alter table term add constraint term_systemwert_key_check check (systemwert_key in (
  'fahrzeit_einfach_std',
  'distanz_einfach_km',
  'distanz_naechstes_kieswerk_km',
  'distanz_naechste_deponie_km',
  'belag_flaeche',
  'belag_flaeche_alle'
));
