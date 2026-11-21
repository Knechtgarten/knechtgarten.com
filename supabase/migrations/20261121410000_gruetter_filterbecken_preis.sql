-- Grütter-Biofilter: echter Einkaufspreis aus Rechnung (Stefan 2026-11-21)
-- Grütter Metallwaren Rechnung Nr. 31'551 vom 15.06.2026 (PEAX), Kom. Sailer (Gümligen):
--   1 Stk. Filterbecken V4A 4200 × 1270 × 1300 mm = CHF 5'590.– (Transport separat verrechnet)
-- Der vorherige Preis 10'250.– war die Preisanfrage «Kirchgässli» (anderes Objekt) und ist ersetzt.
update artikel set
  artikelnummer_lieferant = 'FILTERBECKEN-V4A',
  artikelnummer_knecht = 'GRUETT_FILTERBECKEN_V4A',
  bezeichnung = 'Biofilter-Becken Edelstahl V4A ca. 4.2 × 1.27 × 1.3 m (Grütter)',
  ep_lieferant = 5590,
  notiz = 'Rechnung Grütter Nr. 31''551 vom 15.06.2026, Kom. Sailer Gümligen: Filterbecken V4A 4200×1270×1300 = 5''590.– (Transport separat)'
where artikelnummer_knecht = 'GRUETT_BIOFILTER_1500';

update auswahloption set hinweistext = 'Zusätzlich zur Füllung (Classic/Helix bleibt). Grütter Filterbecken V4A ca. 4.2 × 1.27 × 1.3 m (EK 5''590.– laut Rechnung Sailer 2026, Transport separat). GFK-Gitter ca. 4 m²: gelbe Zeile, Preis eintragen.'
where name = '+ Edelstahlbehälter';

select artikelnummer_knecht, bezeichnung, ep_lieferant, vp_knecht from artikel where artikelnummer_knecht = 'GRUETT_FILTERBECKEN_V4A';
