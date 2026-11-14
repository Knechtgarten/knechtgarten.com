-- Korrektur der Zuteilung vom 14.11. (alle Offerten ohne erstellt_von waren Stefan zugeteilt worden):
-- Fabian = war jeweils zur Erstellungszeit angemeldet (auth.refresh_tokens), Brodbeck = Pascal (Angabe Stefan).
-- Nur Offerten aus der damaligen Zuteilung (Stefan, erstellt vor dem 4.11.2026).
update public.offerte set erstellt_von = (select id from public.benutzer where anzeigename = 'Fabian' limit 1)
where erstellt_von = (select id from public.benutzer where anzeigename = 'Stefan' limit 1) and erstellt_am < '2026-11-04'
  and offertnummer in ('2026-010121','2026-010120','2026-010119','2026-010107','2026-010106','2026-010059','2026-010058',
    '2026-010057','2026-010055','2026-010054','2026-010118','2026-010056','2026-010051','2026-010050','2026-010049',
    '2026-010048','2026-010047','2026-010046','2026-010029','2026-010034','2026-010033','2026-010032','2026-010031',
    '2026-010036','2026-010035','2026-010021','2026-010020','2026-010042','2026-010037','2026-010019','2026-010044','2026-010041');
update public.offerte set erstellt_von = (select id from public.benutzer where anzeigename = 'Pascal' limit 1)
where erstellt_von = (select id from public.benutzer where anzeigename = 'Stefan' limit 1) and erstellt_am < '2026-11-04'
  and offertnummer in ('2026-010110','2026-010105','2026-010104','2026-010078');
