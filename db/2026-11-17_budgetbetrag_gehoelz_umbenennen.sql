-- Artikelstamm: «Budgetbetrag Einzelgehölz …» → «Budgetbetrag für Gehölz …» (Stefan, 17.11.2026)
update public.artikel set bezeichnung = replace(bezeichnung, 'Budgetbetrag Einzelgehölz', 'Budgetbetrag für Gehölz')
where bezeichnung like 'Budgetbetrag Einzelgehölz%'
returning artikelnummer_knecht, bezeichnung, sync_easybill, easybill_id;
