-- Elektroheizung: Shop-Links der neuen Aquasolar-Artikel (Fotos lädt Stefan im Artikelstamm hoch – Shop blockt automatisches Herunterladen)
update artikel a set shop_link = v.link from (values
  ('AQUASOL_131170', 'https://shop.aquasolar.ch/de/ewt-80-70-aus-edelstahl-9kw-16a-mit-regel'),
  ('AQUASOL_131168', 'https://shop.aquasolar.ch/de/ewt-80-70-aus-edelstahl-12kw-20a-mit-regel'),
  ('AQUASOL_131080', 'https://shop.aquasolar.ch/de/steuerung-fur-elektroheizer-3-kw-bis-18-kw'),
  ('AQUASOL_131081', 'https://shop.aquasolar.ch/de/steuerung-fur-elektroheizer-12-15-18kw'),
  ('AQUASOL_131079', 'https://shop.aquasolar.ch/de/ewt-stromungschalter-in-t-stuck-d-50mm-eingebaut'),
  ('AQUASOL_081006', 'https://shop.aquasolar.ch/de/temperaturregler-t-control-1')
) v(nr, link) where a.artikelnummer_knecht = v.nr;
select artikelnummer_knecht, shop_link is not null hat_link from artikel where artikelnummer_knecht in ('AQUASOL_131170','AQUASOL_131168','AQUASOL_131080','AQUASOL_131081','AQUASOL_131079','AQUASOL_081006');
