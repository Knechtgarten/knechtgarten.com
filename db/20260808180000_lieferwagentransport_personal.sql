-- ============================================================================
-- Offertentool 2027 - Lieferwagentransport: zusaetzliche Personal-Variante
-- (Chauffeur) pro Ort. Ein sonderposition_typ hat eine fixe Kategorie - die
-- Fahrzeugkosten (Logistik) und die Lohnkosten des Fahrers (Personal) fuer
-- dieselbe Fahrt koennen darum nicht in EINER Sonderposition stecken. Statt
-- einer neuen "gilt fuer Personal/Lieferwagen"-Auswahl (zu viele
-- Verzweigungen) bekommt jeder Ort einen zweiten, sofort einsatzbereiten
-- sonderposition_typ mit Kategorie Personal - gleiches Rechenprinzip
-- (Fahrzeit x Preis eines zentralen Stundenartikels), nur mit einem eigenen
-- Chauffeur-Lohnartikel statt dem Lieferwagen-Std-Artikel.
--
-- lieferwagen_transport_ort verbindet die Logistik- und die Personal-Variante
-- desselben Orts mit der richtigen Adressliste/Fahrzeit-Berechnung in Tool A
-- (robuster als ueber den frei aenderbaren Namen/Titel zu gehen).
-- ============================================================================

alter table sonderposition_typ add column lieferwagen_transport_ort text null
  check (lieferwagen_transport_ort in ('kieswerk_betonwerk', 'deponie', 'magazin'));

update sonderposition_typ set lieferwagen_transport_ort = 'kieswerk_betonwerk' where name = 'Lieferwagentransport Kieswerk/Betonwerk';
update sonderposition_typ set lieferwagen_transport_ort = 'deponie' where name = 'Lieferwagentransport Deponie';
update sonderposition_typ set lieferwagen_transport_ort = 'magazin' where name = 'Lieferwagentransport Magazin';

insert into sonderposition_typ (name, titel, erklaerung, kategorie, einheit, hat_eigene_berechnung, lieferwagen_transport_ort) values
  ('Lieferwagentransport Kieswerk/Betonwerk Personal', 'Lieferwagenchauffeur Kieswerk/Betonwerk', 'Lohnkosten des Chauffeurs fuer dieselbe Fahrt wie "Lieferwagentransport Kieswerk/Betonwerk" - Fahrzeit (einfache Strecke) x Preis des hinterlegten Chauffeur-Artikels.', 'personal', 'Fahrt', true, 'kieswerk_betonwerk'),
  ('Lieferwagentransport Deponie Personal', 'Lieferwagenchauffeur Deponie', 'Lohnkosten des Chauffeurs fuer dieselbe Fahrt wie "Lieferwagentransport Deponie" - Fahrzeit (einfache Strecke) x Preis des hinterlegten Chauffeur-Artikels.', 'personal', 'Fahrt', true, 'deponie'),
  ('Lieferwagentransport Magazin Personal', 'Lieferwagenchauffeur Magazin', 'Lohnkosten des Chauffeurs fuer dieselbe Fahrt wie "Lieferwagentransport Magazin" - Fahrzeit (einfache Strecke) x Preis des hinterlegten Chauffeur-Artikels.', 'personal', 'Fahrt', true, 'magazin');
