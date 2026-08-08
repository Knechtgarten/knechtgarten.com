-- ============================================================================
-- Offertentool 2027 - Magazin-Adresse vorbefuellen mit dem Firmenstandort.
--
-- Das Magazin/Lager ist am Firmensitz (Badhaus 42, 3615 Heimenschwand) - diese
-- Adresse ist bereits an anderer Stelle (Fahrstrecke/Lieferwagenfahrzeit)
-- hinterlegt, daher hier direkt als erste Zeile vorausgefuellt statt eine
-- leere Liste, die erst manuell befuellt werden muesste.
-- ============================================================================

insert into magazin_adressen (name, adresse, reihenfolge)
values ('Knechtgarten (Hauptsitz)', 'Badhaus 42, 3615 Heimenschwand', 1);
