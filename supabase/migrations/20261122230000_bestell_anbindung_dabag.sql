-- QR-Bestellung: zweites Shop-System Dabag (B-TEAM, später IMMER AG). Optionen pro Anbindung (z. B. Firmenwarenkorb).
-- Leere «bestaetigung» = keine automatische Erkennung (nur «Ist schon bestellt?»), bis die Bestätigungsseite bekannt ist.
alter table public.bestell_anbindung drop constraint if exists bestell_anbindung_plattform_check;
alter table public.bestell_anbindung add constraint bestell_anbindung_plattform_check check (plattform in ('magento', 'dabag'));
alter table public.bestell_anbindung add column if not exists optionen jsonb not null default '{}'::jsonb;
alter table public.bestell_anbindung alter column bestaetigung drop not null;
alter table public.bestell_anbindung alter column sprache drop not null;

insert into public.bestell_anbindung (lieferant_id, plattform, shop_url, sprache, bestaetigung, optionen, beschrieb)
select id, 'dabag', 'https://shop.bteam.ch', null, null, '{"firmenkorb": false}'::jsonb,
  'Dabag. Die Erweiterung nutzt die Direkterfassung im Warenkorb (vollständige Artikelnummer + Menge) und trägt unsere Notiz im Feld «Kommission» der Position ein. Bestätigungsseite noch nicht bekannt: nach dem Abschicken «Ist schon bestellt?» klicken.'
from public.lieferant where name = 'B-TEAM' and archiviert_am is null
on conflict (lieferant_id) do nothing;

select string_agg(plattform || ' ' || shop_url, ', ') from public.bestell_anbindung;
