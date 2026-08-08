-- ============================================================================
-- Offertentool 2027 - Generischen Kieswerk-Distanz-Systemwert wieder entfernen.
--
-- Der Systemwert "Fahrt Baustelle zu naechstem Kieswerk" (kieswerk_distanz)
-- war als generischer Baustein fuer beliebige Menge-Formeln gedacht, wurde
-- aber nie in einer Formel verwendet - die Kies-/Beton-Transport-Berechnung
-- laeuft vollstaendig ueber die Sonderposition (kieswerk_kies/kieswerk_beton,
-- mit eigener Adresspruefung). Nutzer-Entscheid: nur EIN Mechanismus statt
-- zwei sich ueberschneidenden. "Fahrt Baustelle zu naechster Deponie"
-- (deponie_distanz) bleibt bestehen, da dafuer keine Sonderposition existiert.
-- ============================================================================

delete from term where typ = 'systemwert' and systemwert_key = 'distanz_naechstes_kieswerk_km';
drop table if exists kieswerk_distanz;
