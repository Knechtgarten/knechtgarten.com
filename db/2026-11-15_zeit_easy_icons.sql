-- Erste Reihe «Neue Offerte»: Zeit (früher Tagesrechner) · Easy · (KI folgt)
update public.offertentyp set name = 'Zeit', icon_key = 'uhr' where id = '74262461-1f4b-49ee-837a-9e3a1d41c938';
update public.offertentyp set icon_key = 'easystern' where berechnungsmodell = 'easy';
-- leere Tagesrechner-Vorlage «Neue Vorlage» (keine Offerten) in den Papierkorb
update public.offertentyp set papierkorb_am = now() where id = '18673568-0fe8-44a1-b394-8e2dd775d8df' and not exists (select 1 from public.offerte where offertentyp_id = '18673568-0fe8-44a1-b394-8e2dd775d8df');
