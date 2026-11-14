-- Offerten auf die eigenen Namen der Mitarbeitenden (Angabe Stefan 14.11.2026)
update public.offerte set erstellt_von = (select id from public.benutzer where anzeigename = 'Fabian' limit 1)
 where offertnummer in ('2026-010017','2026-010005') and erstellt_am < '2026-11-04';
update public.offerte set erstellt_von = (select id from public.benutzer where anzeigename = 'Benu' limit 1)
 where offertnummer in ('2026-020001','2026-010003') and erstellt_am < '2026-11-04';
update public.offerte set erstellt_von = (select id from public.benutzer where anzeigename = 'Pascal' limit 1)
 where offertnummer in ('2026-010064','2026-010065','2026-010018') and erstellt_am < '2026-11-04';
