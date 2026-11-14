-- Offerten-Status neu: offen (= ohne Status) | bestaetigt (mündlich, ein Häkchen) | zugesagt (Auftrag, zwei Häkchen) | abgelehnt
-- Bisher setzte das Pendenzen-Tool beim Zusagen «bestaetigt» -> diese Offerten sind eigentlich «zugesagt».
alter table public.offerte drop constraint if exists offerte_status_check;
alter table public.offerte add constraint offerte_status_check
  check (status = any (array['offen'::text, 'bestaetigt'::text, 'zugesagt'::text, 'abgelehnt'::text]));
update public.offerte set status = 'zugesagt' where status = 'bestaetigt';

-- «Noch offen»: freie Auflistung, was an der Offerte noch fehlt (leer = nichts offen)
alter table public.offerte add column if not exists noch_offen text;
-- Bereich beim Kunden (z. B. Nordseite, Südseite) – Auswahl = bisherige Bereiche dieses Kunden
alter table public.offerte add column if not exists bereich text;
