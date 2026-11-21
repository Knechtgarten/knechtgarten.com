-- Gartenbeleuchtung › Grundinstallation › Boxen: alle Boxen als eigene Offertenposition (wie Bewässerung).
update auswahloption o set ist_eigene_offertenposition = true
from auswahlfeld f, teilschritt t, arbeitsschritt ar
where f.id = o.auswahlfeld_id and t.id = f.teilschritt_id and ar.id = t.arbeitsschritt_id
  and ar.offertentyp_id = '5ce077fd-3ed6-4985-acb1-9a0fdc17a8c3' and f.name = 'Boxen' and not o.ist_eigene_offertenposition;
select count(*) filter (where o.ist_eigene_offertenposition) separat, count(*) alle
from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt ar on ar.id = t.arbeitsschritt_id
where ar.offertentyp_id = '5ce077fd-3ed6-4985-acb1-9a0fdc17a8c3' and f.name = 'Boxen';
