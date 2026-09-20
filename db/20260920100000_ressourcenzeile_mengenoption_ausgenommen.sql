-- Einzelne Ressourcenzeilen einer Option mit aktiver Mengenoption koennen von
-- deren Anzahl-Multiplikator ausgenommen werden - z.B. eine fixe Montagezeit
-- (Polier/Gartenarbeiter), die nicht mit den eingegebenen Laufmetern skalieren
-- soll, waehrend die eigentliche Material-/Sonderposition (z.B. LED-Band-
-- Staffelung) weiterhin ganz normal mit der Anzahl multipliziert wird.
-- Siehe Tool A recalc() (anzahlFaktor) und Tool B (Icon bei "Mengenoption"-
-- Optionen).
alter table ressourcenzeile add column mengenoption_ausgenommen boolean not null default false;
