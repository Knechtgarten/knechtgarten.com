-- ============================================================================
-- Einsatzplaner: Maschinen-Reservierung vorläufig / fest, Lage relativ zur Baustelle
--
-- planer_ressource.typ_planung   Typ für die Planung, z. B. «Raupenbagger 2 t»
--                                (gleicher Typ = austauschbar, für Vorschläge)
-- planer_ressource_einsatz (Maschine an Baustelle):
--   fest               false = vorläufig (Häkchen), true = fest (Schloss)
--   ab_slot            ab dem n-ten Halbtag der Baustelle (0 = ab Beginn)
--   bis_vor_ende_slot  so viele Halbtage vor dem Ende aufhören (0 = bis Ende)
--   pausen             Unterbrüche als [von, bis) in Halbtagen der Baustelle
-- Dadurch wandert die Reservierung mit, wenn die Baustelle verschoben,
-- verlängert oder einer anderen Person gegeben wird.
-- Die bisherigen Maschinen-Zuteilungen waren Testdaten und werden gelöscht.
-- ============================================================================
alter table planer_ressource add column if not exists typ_planung text null;
alter table planer_ressource_einsatz add column if not exists fest boolean not null default false;
alter table planer_ressource_einsatz add column if not exists ab_slot int not null default 0;
alter table planer_ressource_einsatz add column if not exists bis_vor_ende_slot int not null default 0;
alter table planer_ressource_einsatz add column if not exists pausen jsonb not null default '[]'::jsonb;

delete from planer_ressource_einsatz pe using planer_ressource r where r.id = pe.ressource_id and r.typ = 'maschine';

-- Typen für die bestehenden Maschinen (änderbar unter «Fahrzeuge & Maschinen»)
update planer_ressource set typ_planung = name where typ = 'maschine' and typ_planung is null and name like 'Raupenbagger%';
update planer_ressource set typ_planung = 'Raupendumper gross' where typ = 'maschine' and typ_planung is null and nummer in ('R.1', 'R.7');
update planer_ressource set typ_planung = 'Raupendumper' where typ = 'maschine' and typ_planung is null and nummer in ('R.3', 'R.4');
update planer_ressource set typ_planung = 'Raupendumper klein' where typ = 'maschine' and typ_planung is null and nummer = 'R.2';
update planer_ressource set typ_planung = 'Dumper gross (Radtumper)' where typ = 'maschine' and typ_planung is null and name like 'Dumper gross%';
