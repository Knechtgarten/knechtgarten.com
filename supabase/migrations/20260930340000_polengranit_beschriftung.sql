-- Polengranit: Namen ohne Klammern, Mouse-over (Hinweistext) mit Lkw-Ladung in m² je Blockgrösse
-- Lkw-Ladung: Richtwert 25 t (5-Achs-Sattelzug, steht nicht in der Preisliste), 25 t / (t je m²) = 25 / 22 / 19 m²
update teilschritt set name = 'Polengranit Grossmengen franko geliefert' where name = 'Polengranit Grossmengen (komplett Lkw)';
update teilschritt set name = 'Polengranit Kleinmengen ab Lager Liestal' where name = 'Polengranit Kleinmengen (ab Lager)';
update auswahlfeld set name = 'Polengranit Grossmengen franko geliefert' where name = 'Polengranit Grossmengen (komplett Lkw)';
update auswahlfeld set name = 'Polengranit Kleinmengen ab Lager Liestal' where name = 'Polengranit Kleinmengen (ab Lager)';
update artikel set bezeichnung = replace(replace(bezeichnung, ' (komplett Lkw franko)', ' komplett Lkw franko'), ' (ab Lager Liestal)', ' ab Lager Liestal') where artikelnummer_knecht like 'FONTAR_POLEN_%';

update auswahloption o set hinweistext = case
  when f.name = 'Polengranit Grossmengen franko geliefert' then
    'Komplette Lkw-Ladung, franko geliefert. Ein Lkw (Richtwert ca. 25 t) entspricht bei ' ||
    case when o.name like '30er%' then '30er Blöcken (1.0 t/m²) ca. 25 m²' when o.name like '40er%' then '40er Blöcken (1.15 t/m²) ca. 22 m²' else '50er Blöcken (1.3 t/m²) ca. 19 m²' end ||
    ' Sichtfläche. Preis gilt für Lieferort Liestal, andere Lieferorte bei Fontarocca anfragen. Lieferung auf Paletten ohne Ablad.'
  else
    'Ab Lager Liestal, für Mengen unter einer kompletten Lkw-Ladung (unter ca. ' ||
    case when o.name like '30er%' then '25 m² bei 30er Blöcken' when o.name like '40er%' then '22 m² bei 40er Blöcken' else '19 m² bei 50er Blöcken' end ||
    '). Unter 3 t loses Material oder weniger als 1 Palette: Kleinmengenzuschlag CHF 40 pauschal. Die Fontarocca-Lieferung je Tonne ist als Transport separat enthalten.'
  end
 from auswahlfeld f
 where f.id = o.auswahlfeld_id and f.name in ('Polengranit Grossmengen franko geliefert', 'Polengranit Kleinmengen ab Lager Liestal');
