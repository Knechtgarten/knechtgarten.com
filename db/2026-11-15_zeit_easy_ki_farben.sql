-- Erste Reihe «Neue Offerte»: Zeit Braun, Easy Petrol, KI Violett (Palette, zweithellste Stufe)
update public.offertentyp set farbe_key = 'erde' where berechnungsmodell = 'tagessatz' and name = 'Zeit';
update public.offertentyp set farbe_key = 'petrol' where berechnungsmodell = 'easy';
update public.offertentyp set farbe_key = 'violett' where berechnungsmodell = 'ki';
