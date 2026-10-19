-- Belag-Optionen mit Tabellenverweis duerfen zusammen gewaehlt werden: jedes
-- Produkt (z.B. Piazentina fuer die Terrasse, Travertin fuer den Weg) hat seine
-- eigenen angehakten Flaechen. Vorher war es Einzelauswahl, die Flaechen sind
-- beim Wechsel auf ein anderes Produkt mitgewandert.
update auswahloption o
   set mehrfachauswahl = true
  from auswahlfeld af, teilschritt ts, arbeitsschritt a
 where af.id = o.auswahlfeld_id and ts.id = af.teilschritt_id and a.id = ts.arbeitsschritt_id
   and a.offertentyp_id = 'ae8cece8-1768-4507-9405-5a5d3a6fb81d'
   and o.tabellenverweis is not null;
