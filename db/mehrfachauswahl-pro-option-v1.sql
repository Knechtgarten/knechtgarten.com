-- ============================================================================
-- Offertentool 2027 - Mehrfachauswahl neu pro Option statt fuers ganze
-- Auswahlfeld. Bisher: entweder ALLE Optionen eines Feldes frei kombinierbar,
-- oder ALLE gegenseitig exklusiv. Neu: jede Option hat ihr eigenes Haekchen -
-- Optionen OHNE Haekchen sind untereinander weiterhin exklusiv (wie ein
-- klassisches Einzelauswahlfeld), Optionen MIT Haekchen sind freie
-- Zusatzwahlen und lassen sich mit jeder anderen Option (mit oder ohne
-- Haekchen) kombinieren. Deckt beide bisherigen Faelle als Spezialfall ab
-- (alle Optionen mit Haekchen = wie bisher "Mehrfachauswahl", keine Option
-- mit Haekchen = wie bisher "keine Mehrfachauswahl") - nur ein Mechanismus
-- statt zwei sich ueberschneidenden.
-- ============================================================================

alter table auswahloption add column mehrfachauswahl boolean not null default false;

-- Bestehende Auswahlfelder mit "Mehrfachauswahl" behalten ihr Verhalten -
-- alle ihre Optionen bekommen das Haekchen, damit sich fertig konfigurierte
-- Offerten-Vorlagen durch diese Umstellung nicht unbeabsichtigt aendern.
update auswahloption ao
set mehrfachauswahl = true
from auswahlfeld af
where ao.auswahlfeld_id = af.id and af.mehrfachauswahl = true;

alter table auswahlfeld drop column mehrfachauswahl;
