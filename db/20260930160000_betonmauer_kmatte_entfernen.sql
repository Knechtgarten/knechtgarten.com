-- Betonmauer (Coffra): Armierungsnetz K-Matte gehört nur zu Bodenplatten, nicht zur Mauer.
-- In der Mauer ist nur Armierungsstahl (Stäbe) eingerechnet.
delete from ressourcenzeile rz
 using auswahloption o, artikel a
 where rz.option_id = o.id and a.id = rz.artikel_id
   and o.name in ('Betonmauer gepumpt', 'Betonmauer mit Lieferwagen')
   and a.bezeichnung like 'Armierungsnetz ruwa K-Matte%'
   and rz.option_id in (
     select o2.id from auswahloption o2 join auswahlfeld af on af.id = o2.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
       join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = ar.offertentyp_id
      where ot.name = 'Mauern' and ot.papierkorb_am is null);
