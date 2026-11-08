-- Handy-Startseite: welche Widgets eine Gruppe sieht (Reihenfolge = Liste). Leer (null) = Standard.
-- Schlüssel: erfassen (Pendenz erfassen), pend (Meine Pendenzen heute), einsatz (Mein Einsatz), schnell (Schnellzugriff)
alter table recht_gruppe add column if not exists handy_widgets text[];

-- Neue Gruppe für Schnupper-Tage (1–2 Tage): ohne Rechte-Einträge = sieht nur das Nötigste
insert into recht_gruppe (schluessel, name, bereich, rolle_alt, ist_standard_fuer_rolle, sortierung, handy_widgets)
select 'schnupper', 'Schnupper', 'aussendienst', 'mitarbeitende', false, 80, array['einsatz']
where not exists (select 1 from recht_gruppe where schluessel = 'schnupper');

-- Vorschläge pro Gruppe (später in Einstellungen › Handy-Ansichten änderbar)
update recht_gruppe set handy_widgets = array['erfassen','pend','einsatz','schnell'] where schluessel in ('admin','buero') and handy_widgets is null;
update recht_gruppe set handy_widgets = array['einsatz','erfassen','schnell'] where schluessel in ('pool','va_bau','va_pflege') and handy_widgets is null;
update recht_gruppe set handy_widgets = array['einsatz','erfassen'] where schluessel in ('hilf','temp') and handy_widgets is null;
