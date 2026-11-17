-- Artikelstamm: «Budgetbetrag Solitärgehölz 3K/5K/8K» → «Budgetbetrag für Gehölz 3000/5000/8000» (gleiches Muster wie 300/600/1200, Stefan 17.11.2026)
update public.artikel set bezeichnung = case bezeichnung
    when 'Budgetbetrag Solitärgehölz 3K' then 'Budgetbetrag für Gehölz 3000'
    when 'Budgetbetrag Solitärgehölz 5K' then 'Budgetbetrag für Gehölz 5000'
    when 'Budgetbetrag Solitärgehölz 8K' then 'Budgetbetrag für Gehölz 8000'
  end
where bezeichnung in ('Budgetbetrag Solitärgehölz 3K', 'Budgetbetrag Solitärgehölz 5K', 'Budgetbetrag Solitärgehölz 8K')
returning artikelnummer_knecht, bezeichnung, vp_knecht, easybill_id;
