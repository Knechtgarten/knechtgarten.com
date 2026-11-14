-- Nachtrag: bestehende Offerten, die die Knöpfe schon nutzen, bekommen die Menge aus den (jetzt ausgeblendeten) Spalten
update public.offerte_auswahl a set anzahl = coalesce((
  select sum(coalesce(w.wert, 0)) from public.offerte_tabelle_wert w join public.offerte_tabelle_zeile z on z.id = w.zeile_id
  where z.offerte_id = a.offerte_id and w.spalte_id = case
    when a.option_id in ('4f08273e-efb8-4d0a-8816-467e9fdf7a4a','f3efda6f-555b-484c-a755-2b96ba15922f') then '9ffaff92-2c67-4bed-a820-e88cc26e80ca'::uuid  -- Ecken
    when a.option_id in ('488338df-92f5-4c47-947e-7c938765833c','758c3902-4d67-4215-9f71-5024a241585b') then '83cd04d0-587f-4354-88de-abbdb7884e44'::uuid  -- Abdeckung
    else 'ce50631a-3ccd-4320-912b-5406426e9c10'::uuid end), 0)                                                                                              -- Stirnen
where a.option_id in ('4f08273e-efb8-4d0a-8816-467e9fdf7a4a','f3efda6f-555b-484c-a755-2b96ba15922f','488338df-92f5-4c47-947e-7c938765833c','758c3902-4d67-4215-9f71-5024a241585b','ff34bf33-ffb9-4da1-a0b0-3d2c1c2d6ae9','fd7c5bf0-4852-4706-8bde-df64a25ec629');
select o.name, a.anzahl, f.offertnummer from public.offerte_auswahl a join public.auswahloption o on o.id = a.option_id join public.offerte f on f.id = a.offerte_id
 where a.option_id in ('4f08273e-efb8-4d0a-8816-467e9fdf7a4a','f3efda6f-555b-484c-a755-2b96ba15922f','488338df-92f5-4c47-947e-7c938765833c','758c3902-4d67-4215-9f71-5024a241585b','ff34bf33-ffb9-4da1-a0b0-3d2c1c2d6ae9','fd7c5bf0-4852-4706-8bde-df64a25ec629') order by 3;
