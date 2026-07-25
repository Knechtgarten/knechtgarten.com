-- ============================================================================
-- Offertentool 2027 - Offerten-Positionen fuer Offerten nach Stundenberechnung
-- (Tagessatz/"Allgemein"), analog zu den bestehenden Zeilen fuer Offerten
-- nach Mengenberechnung (siehe db/offerten-position-einstellung-v1.sql).
--
-- Nutzt dieselbe Tabelle offerten_position_einstellung - nur mit eigenen
-- Schluesseln, damit Einheit/Rundung fuer Tagessatz unabhaengig von Formel
-- konfiguriert werden koennen. Analog gilt aktuell nur fuer Personalaufwand
-- und Maschinenaufwand (Material/Logistik bei Tagessatz unveraendert).
-- ============================================================================

insert into offerten_position_einstellung (schluessel, einheit, rundung_menge, rundung_preis) values
  ('personalaufwand_tagessatz', 'Std', 'ganze_zahl', '1_dezimal'),
  ('maschinenaufwand_tagessatz', 'Budg.', 'ganze_zahl', '1_dezimal');
