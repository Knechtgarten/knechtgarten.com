-- Erste Reihe «Neue Offerte» heller (Variante D): Zeit Petrol hell, Easy-Vorlagen Blau hell, KI Violett hell
update public.offertentyp set farbe_key = 'petrolhell' where berechnungsmodell = 'tagessatz' and name = 'Zeit';
update public.offertentyp set farbe_key = 'blauhell' where berechnungsmodell = 'easy';
update public.offertentyp set farbe_key = 'violetthell' where berechnungsmodell = 'ki';
select name, farbe_key from public.offertentyp where berechnungsmodell in ('tagessatz','easy','ki') order by name;
