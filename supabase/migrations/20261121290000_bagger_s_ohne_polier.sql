-- Tagesrechner «Zeit», Maschinentransport Bagger S: keine Polier-Stunden (Stefan 2026-11-21)
-- Das Team fährt so oder so zur Baustelle – nur Lieferwagen + Anhänger für den Bagger zählen.
delete from ressourcenzeile r
using auswahloption o, auswahlfeld f, teilschritt t, arbeitsschritt a, artikel ar
where o.id = r.option_id and f.id = o.auswahlfeld_id and t.id = f.teilschritt_id and a.id = t.arbeitsschritt_id and ar.id = r.artikel_id
  and a.offertentyp_id = '74262461-1f4b-49ee-837a-9e3a1d41c938' and t.name = 'Maschinentransport' and o.name = 'Bagger S'
  and r.kategorie = 'personal';

update auswahloption o set hinweistext = 'Transport durch uns mit Lieferwagen und Anhänger (ohne Personal, das Team fährt ohnehin zur Baustelle): 2 Fahrten hin und zurück Magazin ↔ Kunde + 2 × 0.5 Std. Auf-/Abladen.'
from auswahlfeld f, teilschritt t, arbeitsschritt a
where f.id = o.auswahlfeld_id and t.id = f.teilschritt_id and a.id = t.arbeitsschritt_id
  and a.offertentyp_id = '74262461-1f4b-49ee-837a-9e3a1d41c938' and t.name = 'Maschinentransport' and o.name = 'Bagger S';

select o.name, string_agg(ar.bezeichnung, ' · ' order by r.reihenfolge) zeilen
from ressourcenzeile r join auswahloption o on o.id = r.option_id join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join artikel ar on ar.id = r.artikel_id
where t.name = 'Maschinentransport' group by o.name, o.reihenfolge order by o.reihenfolge;
