-- Mauern: Kleingeräte-Zeile (Maschinen und Geräte Bau …, 0.1 Std.) bei Polengranit entfernen – wie Plasselb (Stefan, 17.11.2026)
-- Betrifft Polengranit Grossmengen franko + Kleinmengen, alle Optionen (8 Zeilen). Korrekturen in Offerten fallen per Cascade mit weg.
delete from ressourcenzeile r
using auswahloption o, auswahlfeld af, teilschritt t, arbeitsschritt a, offertentyp ot, artikel ar
where o.id = r.option_id and af.id = o.auswahlfeld_id and t.id = af.teilschritt_id and a.id = t.arbeitsschritt_id
  and ot.id = a.offertentyp_id and ar.id = r.artikel_id
  and ot.name = 'Mauern' and t.name ilike 'Polengranit%' and ar.bezeichnung ilike 'Maschinen und Geräte Bau%'
returning r.id, t.name, o.name;
