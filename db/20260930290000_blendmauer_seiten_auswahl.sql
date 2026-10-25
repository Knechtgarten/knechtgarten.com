-- Blendmauer, Spalte "Seiten": Dropdown einseitig (1) / beidseitig (2) statt Zahl
update eingabefeld_tabelle_spalte s set auswahl_werte = '[{"text":"einseitig","wert":1},{"text":"beidseitig","wert":2}]'::jsonb, vorschlagswert = 1
 from eingabefeld e join offertentyp ot on ot.id = e.offertentyp_id
 where s.eingabefeld_id = e.id and ot.name = 'Mauern' and ot.papierkorb_am is null and e.name = 'Blendmauer' and s.name = 'Seiten';
