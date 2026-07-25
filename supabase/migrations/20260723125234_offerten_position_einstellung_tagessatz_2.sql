-- ============================================================================
-- Offertentool 2027 - Positionen fuer Offerten nach Stundenberechnung
-- (Tagessatz/"Allgemein"): Ergaenzung um Material- und Logistikaufwand,
-- damit dieser Block wie gefordert vollstaendig identisch zu "Offerten nach
-- Mengenberechnung" ist (siehe db/offerten-position-einstellung-tagessatz-v1.sql
-- fuer Personal-/Maschinenaufwand).
-- ============================================================================

insert into offerten_position_einstellung (schluessel, einheit, rundung_menge, rundung_preis) values
  ('materialaufwand_tagessatz', 'Stk', 'ganze_zahl', '1_dezimal'),
  ('logistikaufwand_tagessatz', 'Budg.', 'ganze_zahl', '1_dezimal');
