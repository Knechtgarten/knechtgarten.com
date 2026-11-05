-- Pooloptionen: Option «Reinigungsset» im Feld «Poolroboter» (zusätzlich zu einem Roboter wählbar, eigene Offertenposition)
-- fehlender Artikel: Kescher tief 182101 (Lieferant wie die übrigen Teile, EK = 50 % wie bei den anderen)
insert into public.artikel (lieferant_id, kategorie, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_lieferant, waehrung, wechselkurs, vp_knecht, sync_easybill)
select 'd792a7b8-cdb5-4443-bd9d-67bdf4a6f87b', 'material', '182101', 'Kescher tief, Bodenkescher mit Aluminiumrahmen und grosser Aufnahmelippe', 'Stk.', 20, 40, 'CHF', 1, 40, true
where not exists (select 1 from public.artikel where artikelnummer_lieferant = '182101' and lieferant_id = 'd792a7b8-cdb5-4443-bd9d-67bdf4a6f87b');

with o as (
  insert into public.auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, mehrfachauswahl, ist_eigene_offertenposition, mengenoption)
  values ('56621d27-607c-4b56-9c5e-d6de1d6f0a19', 'Reinigungsset', 3,
    'Reinigungsset für die Handreinigung liefern: Teleskopstange 2,4–4,8 m mit Excenter, Kescher tief, Bürste gebogen 45 cm und Pool''Gom XL Bürste mit Gummi.',
    'Teleskopstange, Kescher, Bürste, Pool''Gom XL – auch zusätzlich zu einem Roboter wählbar.', true, true, false)
  returning id)
insert into public.ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge, ist_eigene_offertenposition, menge_formel_modus, mengenoption_ausgenommen)
select o.id, 'material', a.id, '{"lit": 1, "_einheit": "Stk."}'::jsonb, 1, 1, 1, 1, x.r, false, 'baukasten', false
from o, (values ('182053', 1), ('182101', 2), ('182035', 3), ('061111', 4)) as x(nr, r)
join public.artikel a on a.artikelnummer_lieferant = x.nr and a.lieferant_id = 'd792a7b8-cdb5-4443-bd9d-67bdf4a6f87b';
