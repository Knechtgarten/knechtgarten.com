-- Farben im Fenster «Neue Offerte»: Regenwassertank wie Bewässerung/Gartenbeleuchtung (hellgrau), Tagesrechner eigene Farbe (blau)
update public.offertentyp set farbe_key = 'hellgrau' where name = 'Regenwassertank';
update public.offertentyp set farbe_key = 'blau' where name = 'Tagesrechner';
select name, farbe_key from public.offertentyp where name in ('Regenwassertank','Tagesrechner','Bewässerung','Gartenbeleuchtung');
