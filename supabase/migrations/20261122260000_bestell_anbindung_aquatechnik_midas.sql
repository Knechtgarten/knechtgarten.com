-- QR-Bestellung: Aqua-Technik (Magento ohne Sprache im Pfad) und MIDAS (PrestaShop).
alter table public.bestell_anbindung drop constraint if exists bestell_anbindung_plattform_check;
alter table public.bestell_anbindung add constraint bestell_anbindung_plattform_check check (plattform in ('magento', 'dabag', 'hybris', 'prestashop'));
insert into public.bestell_anbindung (lieferant_id, plattform, shop_url, sprache, bestaetigung, optionen, beschrieb)
select id, 'magento', 'https://www.aqua-technik-shop.de', null, '/checkout/onepage/success', '{}'::jsonb,
  'Magento (ohne Sprache in der Adresse). Wie Aquasolar: Artikelnummer über die Produktsuche des Shops, Menge über die normale Warenkorb-Funktion. Kein Notizfeld pro Position.'
from public.lieferant where name ilike 'Aquatechnik%' and archiviert_am is null
on conflict (lieferant_id) do nothing;
insert into public.bestell_anbindung (lieferant_id, plattform, shop_url, sprache, bestaetigung, optionen, beschrieb)
select id, 'prestashop', 'https://webshop.midas-gmbh.de', 'de', null, '{}'::jsonb,
  'PrestaShop. Die Erweiterung sucht die Artikelnummer (Referenz) über die Shopsuche und legt die Menge über die Warenkorb-Funktion hinein (mindestens die Mindestmenge). Kein Notizfeld pro Position. Bestätigungsseite noch nicht bekannt: nach dem Abschicken «Ist schon bestellt?» klicken.'
from public.lieferant where name ilike 'MIDAS%' and archiviert_am is null
on conflict (lieferant_id) do nothing;
select string_agg(plattform || ' ' || shop_url, ', ') from public.bestell_anbindung;
