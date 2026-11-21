-- Speck Badu Alpha 6: Einkaufspreis Aquasolar (Händlerpreis im Shop, 21.11.2026) CHF 324.–, Listenpreis 540.– bleibt VP
update artikel set ep_lieferant = 324, notiz = 'Aquasolar Katalog Kap. 3 Filterpumpen, Rabattgruppe C; EK = Shop-Händlerpreis 21.11.2026'
where artikelnummer_knecht = 'AQUASOL_033260';
select artikelnummer_knecht, ep_lieferant, vp_lieferant, vp_knecht from artikel where artikelnummer_knecht = 'AQUASOL_033260';
