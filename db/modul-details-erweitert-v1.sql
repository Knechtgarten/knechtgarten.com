-- ============================================================================
-- Offertentool 2027 - Kachel-Details erweitert: getrennter Titel fuer
-- Gross/Mittel/Klein statt einem gemeinsamen Titel fuer Gross+Mittel, dazu
-- ein Beschreibungstext (nur in "Gross" sichtbar) und eine waehlbare
-- Hintergrundfarbe je Kachel - bisher fest im HTML der Tools-Startseite
-- hinterlegt, jetzt in der Verwaltung pflegbar.
--
-- "name" bleibt bestehen und wird zum Titel fuer "Gross" (bisher eh schon
-- dafuer verwendet); "kurzname" bleibt der Titel fuer "Klein". Neu:
-- titel_mittel und text_gross.
-- ============================================================================

alter table modul_sichtbarkeit add column titel_mittel text;
alter table modul_sichtbarkeit add column text_gross text;
alter table modul_sichtbarkeit add column hintergrund text not null default 'grau'
  check (hintergrund in ('blau', 'gruen', 'grau', 'navy'));

update modul_sichtbarkeit set titel_mittel = name where titel_mittel is null;

update modul_sichtbarkeit set text_gross = 'Kundenanfragen schnell und einfach bearbeiten.' where modul_key = 'kundenanfragen';
update modul_sichtbarkeit set text_gross = 'Einfaches Berechnen von Volumen, Gewichten, Flächen und vielem mehr.' where modul_key = 'berechnungstool';
update modul_sichtbarkeit set text_gross = 'Verwaltung und Planung von Arbeitssicherheitsmitteln.' where modul_key = 'arbeitssicherheit';
update modul_sichtbarkeit set text_gross = 'Einfache Bestellprozesse bei unseren Lieferanten.' where modul_key = 'bestellungen';
update modul_sichtbarkeit set text_gross = 'Einfaches Beraten, Planen und Bestellen von Pflanzen.' where modul_key = 'pflanzplanung';
update modul_sichtbarkeit set text_gross = 'Tool zum einfachen Erstellen von Offerten.' where modul_key = 'offertentool';

-- Bisheriges Aussehen beibehalten: Offertentool war gruen (".hero.live"),
-- alle anderen (noch "In Planung") waren neutral/grau.
update modul_sichtbarkeit set hintergrund = 'gruen' where modul_key = 'offertentool';
