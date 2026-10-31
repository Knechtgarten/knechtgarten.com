-- Artikelstamm: zwei Aquasolar-Duschen (Fotos werden separat im Storage abgelegt).
-- EP = Händlerpreis laut Shop (UVP minus 40 %), VK = Bruttopreis UVP, wie bei den anderen Aquasolar-Artikeln.
do $$
declare aq uuid; n int;
begin
  select id into aq from lieferant where name = 'Aquasolar';
  if aq is null then raise exception 'Lieferant Aquasolar nicht gefunden'; end if;
  if exists (select 1 from artikel where lieferant_id = aq and artikelnummer_knecht in ('AQUASOL_163021', 'AQUASOL_163024')) then raise exception 'Duschen existieren schon'; end if;
  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, shop_link, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values
    (gen_random_uuid(), aq, 'material', 'AQUASOL_163021', '163021', 'Dusche Norderney Typ EHM Modell 70 / Edelstahl V4A mit Fussbrause', 'Stk.', 946, 1580, 'CHF', 1, 8.1,
     'Hersteller-Nr. 706595, EAN 4039474011706. UVP brutto CHF 1580.', 'https://shop.aquasolar.ch/de/dusche-norderney-typ-ehm', false, false, false, false, false),
    (gen_random_uuid(), aq, 'material', 'AQUASOL_163024', '163024', 'Dusche Sylt Typ EHM mit Handbrause Modell 70, Edelstahl V4A', 'Stk.', 924, 1543, 'CHF', 1, 8.1,
     'Hersteller-Nr. 706590, EAN 4039474011683. UVP brutto CHF 1543.', 'https://shop.aquasolar.ch/de/dusche-sylt-typ-ehm-mit-handbrause', false, false, false, false, false);
  get diagnostics n = row_count;
  if n <> 2 then raise exception 'Erwartet 2 Artikel, angelegt %', n; end if;
end $$;
