-- Welche Vorauswahl gerade auf einer Offerte "aktiv" ist, muss zuverlaessig
-- gespeichert werden - nicht nur im Browser-Speicher und nicht aus der
-- aktuellen Auswahl zurueckgeraten (das ging beim Wechseln zwischen Offerten
-- oder nach manuellen Anpassungen kaputt). on delete set null: wird eine
-- Vorauswahl geloescht, bleibt die Offerte bestehen, zeigt aber keine
-- Vorauswahl mehr als aktiv an.
alter table offerte add column vorauswahl_id uuid null references vorauswahl(id) on delete set null;
