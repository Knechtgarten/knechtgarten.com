-- Standard-Vorauswahl-Konzept wieder entfernt: der Nutzer will keine
-- automatische Uebernahme bei neuen Offerten - eine "Standard" ist einfach
-- eine ganz normale Vorauswahl mit diesem Namen, die man selbst anklickt.
drop index if exists vorauswahl_ein_standard_je_typ;
alter table vorauswahl drop column if exists ist_standard;
