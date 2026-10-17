-- Dropdown-Spalte in Eingabe-Tabellen (z.B. "Belag" in der Flaechentabelle):
-- Pro Zeile waehlt der Mitarbeiter in Tool A einen Teilschritt, der in Tool B
-- mit "Als Belag fuer Flaechen anbieten" (teilschritt.ist_belag) markiert ist.
-- Die Spalte ist generisch gedacht (Spaltenname frei, nicht nur "Belag").
--   ist_dropdown       : Spalte ist eine Auswahl statt einer Zahl
--   dropdown_leer_label: Text der leeren Auswahl (leer = "– nicht zugeordnet –")
--   dropdown_pflicht   : true = keine leere Auswahl, Zuordnung ist Pflicht
alter table eingabefeld_tabelle_spalte add column ist_dropdown boolean not null default false;
alter table eingabefeld_tabelle_spalte add column dropdown_leer_label text null;
alter table eingabefeld_tabelle_spalte add column dropdown_pflicht boolean not null default false;
