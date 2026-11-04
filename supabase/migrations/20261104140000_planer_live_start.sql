-- Einsatzplaner live starten: alle Balken (Baustellen, Mithilfe, Termine), Maschinen-/Fahrzeug-Buchungen,
-- Markierungen, Planer-Pendenzen und Vorschlag-Notizen löschen.
-- Bleiben: Abwesenheiten, Personen, Gruppen, Ressourcen, Feiertage, Abwesenheitsarten, Bauprogramme, Projekte, Kunden.
-- Vorher Sicherung in Schema «sicherung» (planer_*_20261104).
create schema if not exists sicherung;
create table sicherung.planer_einsatz_20261104 as select * from planer_einsatz;
create table sicherung.planer_ressource_einsatz_20261104 as select * from planer_ressource_einsatz;
create table sicherung.planer_markierung_20261104 as select * from planer_markierung;
create table sicherung.planer_pendenz_20261104 as select * from planer_pendenz;
create table sicherung.planer_vorschlag_notiz_20261104 as select * from planer_vorschlag_notiz;
create table sicherung.bauprogramm_20261104 as select * from bauprogramm;
revoke all on all tables in schema sicherung from anon, authenticated;

delete from planer_ressource_einsatz;
delete from planer_einsatz where art <> 'absenz';
delete from planer_markierung;
delete from planer_pendenz;
delete from planer_vorschlag_notiz;

select art, count(*) from planer_einsatz group by art;
