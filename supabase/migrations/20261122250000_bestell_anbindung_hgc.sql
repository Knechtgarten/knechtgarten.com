-- QR-Bestellung: HGC (SAP Commerce / Hybris, eigene Schnittstelle /de/api/…). Bestellmenge in der Bestelleinheit des Shops.
alter table public.bestell_anbindung drop constraint if exists bestell_anbindung_plattform_check;
alter table public.bestell_anbindung add constraint bestell_anbindung_plattform_check check (plattform in ('magento', 'dabag', 'hybris'));
insert into public.bestell_anbindung (lieferant_id, plattform, shop_url, sprache, bestaetigung, optionen, beschrieb)
select id, 'hybris', 'https://www.hgc.ch', 'de', null, '{}'::jsonb,
  'SAP Commerce (Hybris). Die Erweiterung sucht die Artikelnummer über die Produktschnittstelle des Shops und legt sie in der Bestelleinheit des Shops in den Warenkorb (wie das Feld «Artikel hinzufügen»). Notiz/Kommission wird bei HGC noch nicht übertragen. Bestätigungsseite noch nicht bekannt: nach dem Abschicken «Ist schon bestellt?» klicken.'
from public.lieferant where name = 'HG Commerciale' and archiviert_am is null
on conflict (lieferant_id) do nothing;
select string_agg(plattform || ' ' || shop_url, ', ') from public.bestell_anbindung;
