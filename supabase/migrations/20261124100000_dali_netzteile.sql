-- Dali-Netzteile (Staub Designlight, Preisliste 03-2025 v1.2, S. 39) als Artikel
-- + Stufen der Summen-Staffel «Netzteil DALI dimmbar» (netzteil_dali_watt_summe)
with neu as (
  insert into artikel (artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, kategorie,
    lieferant_id, mwst_art, preis_gesperrt, vp_knecht, waehrung, wechselkurs,
    sync_easybill, sync_offertentool, sync_webtool, nur_lager, haendischer_abgleich, foto_url)
  select 'STAUBD_' || v.nr, v.nr, v.bez, 'Stk', 'material',
    'a9a1c247-e8c0-45dd-b959-f8ce7c85794e', 'normal', true, v.vp, 'CHF', 1,
    false, false, false, false, false,
    'https://www.staub-designlight.ch/media/c0/70/c4/1704185443/Netzgeraet_100W-12V_PC060065_01.png'
  from (values
    ('20.124042', 'Netzgerät 50 Watt, 24VDC, inkl. DALI LED Dimmer', 418),
    ('20.124102', 'Netzgerät 100 Watt, 24VDC, inkl. DALI LED Dimmer', 478),
    ('20.124202', 'Netzgerät 200 Watt, 24VDC, inkl. DALI LED Dimmer', 528),
    ('20.124302', 'Netzgerät 300 Watt, 24VDC, inkl. DALI LED Dimmer', 588)
  ) as v(nr, bez, vp)
  where not exists (select 1 from artikel a where a.artikelnummer_knecht = 'STAUBD_' || v.nr)
  returning id, artikelnummer_lieferant
)
insert into staffelstufe (staffelgruppe_id, menge_von, menge_bis, artikel_id, reihenfolge)
select '63d82d87-caf6-4d27-93f8-9c38f9340526', s.von, s.bis, neu.id, s.rf
from neu join (values
  ('20.124042', 0, 50, 1),
  ('20.124102', 50, 100, 2),
  ('20.124202', 100, 200, 3),
  ('20.124302', 200, null, 4)
) as s(nr, von, bis, rf) on s.nr = neu.artikelnummer_lieferant;
