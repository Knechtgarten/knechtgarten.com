-- Bepflanzung › Pflanzarbeit und Lieferung: Gehölz 300 / 600 / 1200 als eigene Offertenposition (wie Solitärgehölz),
-- damit in der Offerte «Budgetbetrag Einzelgehölz 1200 · Anzahl Stk. · 1200.–» steht statt in «Material Pflanzarbeit» versteckt (Stefan, 17.11.2026)
update public.auswahloption set ist_eigene_offertenposition = true
where id in ('76953123-ff44-4614-9b55-e0c7ae6cf149', 'd60225cc-21f3-436d-8b99-18f0cdf40f37', 'c096008e-40e7-496c-ad88-5d530e5d5364')
returning name, ist_eigene_offertenposition;
