-- ============================================================================
-- Offertentool 2027 - Systemwert-Keys um Kieswerk-/Deponie-Distanz erweitern.
--
-- Die bestehende Check-Constraint term_systemwert_key_check erlaubte bisher
-- nur die zwei urspruenglichen Keys (fahrzeit_einfach_std, distanz_einfach_km).
-- Die zwei neueren Systemwerte "Fahrt Baustelle zu naechstem Kieswerk"/
-- "...zu naechster Deponie" (distanz_naechstes_kieswerk_km,
-- distanz_naechste_deponie_km, siehe SYSTEMWERT_TERM_FIX_LISTE in Tool B)
-- wurden dadurch beim automatischen Anlegen von der Datenbank stillschweigend
-- abgelehnt (Constraint-Verletzung, nur in der Browser-Konsole sichtbar) -
-- darum fehlten sie im Auswahl-Picker, egal wie oft man neu geladen hat.
-- ============================================================================

alter table term drop constraint if exists term_systemwert_key_check;
alter table term add constraint term_systemwert_key_check check (systemwert_key in (
  'fahrzeit_einfach_std',
  'distanz_einfach_km',
  'distanz_naechstes_kieswerk_km',
  'distanz_naechste_deponie_km'
));
