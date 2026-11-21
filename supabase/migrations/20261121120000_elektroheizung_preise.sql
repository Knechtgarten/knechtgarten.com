-- Elektroheizung: Preise aus dem Aquasolar-Shop (Stand 2026-11-21, Händler-Login Stefan):
-- ep_lieferant = «Preis» (Einkauf Knecht), vp_lieferant = «Bruttopreis UVP» (= Behncke-Katalog 2026).
-- Korrigiert die Listenpreise 729 → 739 (9 kW) und 830 → 833 (12 kW). VP Knecht rechnet der Trigger neu.
update artikel a set ep_lieferant = v.ep, vp_lieferant = v.uvp from (values
  ('AQUASOL_131170', 443, 739), ('AQUASOL_131168', 499, 833), ('AQUASOL_131080', 177, 295),
  ('AQUASOL_131081', 220, 367), ('AQUASOL_131079', 85, 142),  ('AQUASOL_081006', 353, 588)
) v(nr, ep, uvp) where a.artikelnummer_knecht = v.nr;
select artikelnummer_knecht nr, ep_lieferant ep, vp_lieferant uvp, vp_knecht vp from artikel
where artikelnummer_knecht in ('AQUASOL_131170','AQUASOL_131168','AQUASOL_131080','AQUASOL_131081','AQUASOL_131079','AQUASOL_081006') order by 1;
