-- Das alte, pro Option gesetzte "Standard"-Haekchen ist durch die neuen
-- Vorauswahlen ersetzt (siehe 20260918220000_vorauswahl.sql) - kein Code
-- greift mehr auf diese Spalte zu.
alter table auswahloption drop column ist_standard;
