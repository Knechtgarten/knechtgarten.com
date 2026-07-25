-- ============================================================================
-- Offertentool 2027 - Titel (gross/mittel + klein) und Icon pro Kachel
-- neu in modul_sichtbarkeit, damit der Admin sie in der Verwaltung pflegen
-- kann statt fest im HTML der Tools-Startseite. Zusaetzlich bekommt das
-- Offertentool selbst (bisher nicht in modul_sichtbarkeit, weil immer fuer
-- alle sichtbar) hier eine eigene Zeile - nur fuer Titel/Icon, die
-- Sichtbarkeits-Spalten bleiben fuer diese Zeile ungenutzt (Offertentool
-- bleibt im Code weiterhin immer sichtbar, unabhaengig von diesen Werten).
-- ============================================================================

alter table modul_sichtbarkeit add column kurzname text;
alter table modul_sichtbarkeit add column icon_key text not null default 'dokument';

update modul_sichtbarkeit set kurzname = 'Kunden', icon_key = 'person' where modul_key = 'kundenanfragen';
update modul_sichtbarkeit set kurzname = 'Rechner', icon_key = 'rechner' where modul_key = 'berechnungstool';
update modul_sichtbarkeit set kurzname = 'Sicherheit', icon_key = 'sicherheit' where modul_key = 'arbeitssicherheit';
update modul_sichtbarkeit set kurzname = 'Bestellung', icon_key = 'box' where modul_key = 'bestellungen';
update modul_sichtbarkeit set kurzname = 'Pflanzen', icon_key = 'pflanze' where modul_key = 'pflanzplanung';

insert into modul_sichtbarkeit (modul_key, name, kurzname, icon_key, fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values ('offertentool', 'Offertentool', 'Offerten', 'dokument', true, true, true);
