-- Anhänger 2-Achser mit fester Brücke (Stefan 2026-11-21), aus Easybill-Artikel 10-000120: EK 78.–, VP 98.– pro Std.
-- Für den Bagger-S-Transport im Tagesrechner (Lieferwagen + Anhänger, Kunde ↔ Magazin).
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, mwst_art, preis_gesperrt, sync_offertentool, notiz)
select 'db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'logistik', '10-000120', 'KNECHT_000104', 'Anhänger 2-Achser mit fester Brücke', 'Std.', 78, 98, 'CHF', 'normal', true, true, 'Easybill-Artikel 10-000120'
where not exists (select 1 from artikel where artikelnummer_knecht = 'KNECHT_000104');

select artikelnummer_knecht, bezeichnung, einheit, ep_lieferant, vp_knecht, kategorie from artikel where artikelnummer_knecht = 'KNECHT_000104';
