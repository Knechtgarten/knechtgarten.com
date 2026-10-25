-- Pflästerer-Fremdleistungen: Marge 12 % statt 20 % (VK = EK x 1.12)
update artikel set vp_knecht = round(ep_lieferant * 1.12, 2)
 where artikelnummer_knecht in ('KNECHT_PFLAESTERUNG_REIHEN_SPLITBETON', 'KNECHT_PFLAESTERUNG_BOGEN_SPLITBETON', 'KNECHT_PFLAESTERUNG_REIHEN_SPLIT', 'KNECHT_PFLAESTERUNG_BOGEN_SPLIT', 'KNECHT_PFLAESTERUNG_RANDABSCHLUSS');

-- Pflastersteine Fontarocca AG (Preisliste PL Outdoor 2026, Liestal, Preise je to; VK = EK x 1.05 wie bei den übrigen Fontarocca-Artikeln)
do $$
declare fo uuid; rec record;
begin
  select id into fo from lieferant where name = 'Fontarocca AG';
  if fo is null then raise exception 'Fontarocca AG nicht gefunden'; end if;
  for rec in select * from (values
      ('FONTAR_PFL_GRANIT_P9_11',  'Pflasterstein Granit grau fein/mittelkorn (Portugal) P 9/11 rings gespalten', 282, 'Bedarf ca. 200 kg/m², VE ca. 1.5 to'),
      ('FONTAR_PFL_GUBER_8_11',    'Pflasterstein Guber Quarzsandstein (Schweiz) 8/11 rings gespalten',          873, 'Bedarf ca. 188 kg/m², VE ca. 1.2 to'),
      ('FONTAR_PFL_GUBER_TYP12',   'Pflasterstein Guber Quarzsandstein (Schweiz) Typ 12 rings gespalten',        852, 'Bedarf ca. 250 kg/m², VE ca. 1.2 to'),
      ('FONTAR_PFL_GUBER_WILD',    'Wildpflaster Guber Quarzsandstein (Schweiz) 2-6/8-11 rings gespalten',       457, 'Bedarf ca. 185 kg/m², VE ca. 1.2 to'),
      ('FONTAR_PFL_LUSERNA_DOREE', 'Pflasterstein Luserna Dorée (Italien) P 8/12 Standard rings gespalten',      353, 'Bedarf ca. 200 kg/m², VE ca. 2 to')
    ) as v(nr, bez, ep, anm) loop
    insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
    values (gen_random_uuid(), fo, 'material', rec.nr, rec.nr, rec.bez, 't', rec.ep, round(rec.ep * 1.05), 'CHF', 1, 8.1, rec.anm, false, false, false, true, false);
  end loop;
end $$;
