-- QR-Bestellung: IMMER AG (Dabag, ohne Direkterfassung → Artikelseite + «In den Warenkorb», Kommission direkt mit, ganze Packungen)
insert into public.bestell_anbindung (lieferant_id, plattform, shop_url, sprache, bestaetigung, optionen, beschrieb)
select id, 'dabag', 'https://www.immerag.ch', null, null, '{}'::jsonb,
  'Dabag (ohne Direkterfassung). Die Erweiterung sucht die vollständige Artikelnummer (springt auf die Artikelseite), legt die Menge über «In den Warenkorb» hinein und gibt unsere Notiz als Kommission mit. Viele Artikel nur in ganzen Packungen (z. B. 50er-Schritte): wird aufgerundet und gemeldet. Bestätigungsseite noch nicht bekannt: nach dem Abschicken «Ist schon bestellt?» klicken.'
from public.lieferant where name = 'IMMER AG' and archiviert_am is null
on conflict (lieferant_id) do nothing;
select string_agg(plattform || ' ' || shop_url, ', ') from public.bestell_anbindung;
