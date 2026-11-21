-- Wasserspiel (Stefan 2026-11-21)
-- Artikel: Speck Badu Alpha 6, 230 V (Aquasolar, Speck-Nr. 033260, Listenpreis CHF 540, Aquasolar: VP Lieferant = VP Knecht; EK noch offen)
--          Wasserfall Budgetbetrag CHF 2'500 (Knecht)
-- Neuer Arbeitsschritt «Wasserspiel» (eigene Offertenposition):
--   Pool/Wassergarten: «Wasserspiel Naturteich» (Sibo Pumpe Wasserspiel 5000 l/h) und «Wasserspiel Chemiepool» (Badu Alpha 6)
--   Naturteich/Schwimmteich: «Wasserspiel Naturteich»
--   Beide gleich bis auf die Pumpe: Wasserfall-Budget, 2 Kugelhahnen d 63, 2 PVC-Rohre d 63, 3 Bogen, 3 Muffen,
--   2 Verschraubungen (Anschluss Pumpe), 15 m Flexschlauch d 63, Hilfsmaterial, Polier Wassergärten 4 Std. (Annahme).
-- Pool › Pooltechnik › Umwälzpumpe: neue Option «Badu Alpha 6» (als alleinige Pumpe, Zubehör wie «Pumpe Badebr.»).

insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_lieferant, waehrung, mwst_art, preis_gesperrt, sync_offertentool, notiz)
select l.id, 'material', '033260', 'AQUASOL_033260', 'Speck Schwimmbadpumpe Badu Alpha 6, 230 V (0.18 kW, 3.0 m³/h bei 10 mWs, Ein-/Ausgang 50 mm)', 'Stk.', 540, 'CHF', 'normal', false, true, 'Aquasolar Katalog Kap. 3 Filterpumpen, Rabattgruppe C; EK noch erfassen'
from lieferant l where l.name = 'Aquasolar'
  and not exists (select 1 from artikel where artikelnummer_knecht = 'AQUASOL_033260');

insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht, waehrung, mwst_art, preis_gesperrt, sync_offertentool)
select 'db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'material', 'WASSERFALL-BUDGET', 'KNECHT_WASSERFALL_BUDGET', 'Budgetbetrag Wasserfall (Wasserspiel)', 'Budg', 2500, 'CHF', 'normal', true, true
where not exists (select 1 from artikel where artikelnummer_knecht = 'KNECHT_WASSERFALL_BUDGET');

-- Arbeitsschritt «Wasserspiel» am Schluss der beiden Vorlagen
do $$
declare
  v uuid; a uuid; t uuid;
begin
  foreach v in array array['83bf9ae8-3095-4194-a9bb-4ea2dc08473e', 'bcc55d19-7e61-4fc8-80d0-0889c3148896']::uuid[] loop
    if exists (select 1 from arbeitsschritt where offertentyp_id = v and name = 'Wasserspiel') then continue; end if;
    insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
    values (v, 'Wasserspiel', (select max(reihenfolge) + 1 from arbeitsschritt where offertentyp_id = v)) returning id into a;
    insert into teilschritt (arbeitsschritt_id, name, reihenfolge) values (a, 'Wasserspiel', 1) returning id into t;
    insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (t, 'Wasserspiel', 1);
  end loop;
end $$;

-- Optionen mit Zeilen (pro Vorlage), Pumpe je nach Variante
do $$
declare
  sibo uuid; badu uuid; f record; o uuid; var record;
begin
  select id into sibo from artikel where artikelnummer_knecht = 'SIBOFL_RD626';
  select id into badu from artikel where artikelnummer_knecht = 'AQUASOL_033260';
  for f in
    select f2.id, a.offertentyp_id ot from auswahlfeld f2 join teilschritt t on t.id = f2.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
    where a.name = 'Wasserspiel' and t.name = 'Wasserspiel' and a.offertentyp_id in ('83bf9ae8-3095-4194-a9bb-4ea2dc08473e', 'bcc55d19-7e61-4fc8-80d0-0889c3148896')
  loop
    for var in select * from (values
        (1, 'Wasserspiel Naturteich', sibo, 'Pumpe Sibo Wasserspiel 5000 l/h.'),
        (2, 'Wasserspiel Chemiepool', badu, 'Pumpe Speck Badu Alpha 6 (geeignet für Chlorwasser).')
      ) x(rf, name, pumpe, hinweis)
      where x.rf = 1 or f.ot = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' loop
      if exists (select 1 from auswahloption where auswahlfeld_id = f.id and name = var.name) then continue; end if;
      insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition)
      values (f.id, var.name, var.rf,
        'Wasserspiel mit Wasserfall erstellen. Pumpe, Kugelhahnen, PVC-Leitungen und Flexschlauch liefern, montieren und anschliessen. Wasserfall gemäss Budgetbetrag.',
        var.hinweis || ' Inkl. Wasserfall-Budget CHF 2''500, 2 Kugelhahnen d 63, 2 PVC-Rohre, 3 Bogen, 3 Muffen, 2 Verschraubungen, 15 m Flexschlauch, 4 Std. Polier.',
        false, false, false, true) returning id into o;
      insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
      select o, ar.kategorie, ar.id, jsonb_build_object('lit', z.m, '_einheit', ar.einheit), 'baukasten', 1, 1, 1, 1, z.rf
      from (values
        (1, 'KNECHT_000015', 4::numeric),
        (2, null, 1),
        (3, 'KNECHT_WASSERFALL_BUDGET', 1),
        (4, 'AQUASOL_093206', 2),
        (5, 'AQUASOL_094015', 2),
        (6, 'AQUASOL_091047', 3),
        (7, 'AQUASOL_091278', 3),
        (8, 'AQUASOL_091747', 2),
        (9, 'AQUASOL_095021', 15),
        (10, 'KNECHT_00P075', 1)
      ) z(rf, nr, m)
      join artikel ar on ar.id = coalesce((select id from artikel where artikelnummer_knecht = z.nr), case when z.rf = 2 then var.pumpe end);
    end loop;
  end loop;
end $$;

-- Badu Alpha 6 als alleinige Umwälzpumpe (Pool › Pooltechnik), Zubehör wie «Pumpe Badebr.»
do $$
declare
  vorlage record; badu uuid; o uuid; badebr_pumpe uuid;
begin
  select id into badu from artikel where artikelnummer_knecht = 'AQUASOL_033260';
  select id into badebr_pumpe from artikel where artikelnummer_knecht = 'WELLNE_WW3312620-14EU';
  select * into vorlage from auswahloption where id = '9e7fddac-06b6-41d8-a464-8b5dbe395c12';
  if exists (select 1 from auswahloption where auswahlfeld_id = vorlage.auswahlfeld_id and name = 'Badu Alpha 6') then return; end if;
  update auswahloption set reihenfolge = reihenfolge + 1 where auswahlfeld_id = vorlage.auswahlfeld_id and reihenfolge > vorlage.reihenfolge;
  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition, optionsgruppe_id, optionsgruppe_name)
  values (vorlage.auswahlfeld_id, 'Badu Alpha 6', vorlage.reihenfolge + 1, 'Schwimmbadpumpe Speck Badu Alpha 6 liefern und montieren.',
    'Kleine Schwimmbadpumpe für kleine Pools und Wasserspiele: 0.18 kW, 3.0 m³/h bei 10 mWs, Ein-/Ausgang 50 mm.',
    false, vorlage.mengenoption, vorlage.mengenoption_einheit, vorlage.mehrfachauswahl, vorlage.ist_eigene_offertenposition, vorlage.optionsgruppe_id, vorlage.optionsgruppe_name)
  returning id into o;
  insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, mindestmenge, verschnitt_prozent, sonderposition_typ_id, reihenfolge, menge_formel_modus, mengenoption_ausgenommen)
  select o, r.kategorie, case when r.artikel_id = badebr_pumpe then badu else r.artikel_id end, case when r.artikel_id = badebr_pumpe then null else r.bezeichnung_override end,
    r.menge_ausdruck, case when r.artikel_id = badebr_pumpe then null else r.preis_override end, r.notiz, r.zugang_stufe1, r.zugang_stufe2, r.zugang_stufe3, r.zugang_stufe4,
    r.mindestmenge, r.verschnitt_prozent, r.sonderposition_typ_id, r.reihenfolge, coalesce(r.menge_formel_modus, 'baukasten'), r.mengenoption_ausgenommen
  from ressourcenzeile r where r.option_id = vorlage.id
    and r.artikel_id is distinct from (select id from artikel where artikelnummer_knecht = 'WELLCOM_WW400-1990'); -- Verschraubung nur für Badebrunnen-Pumpe
end $$;

select ot.name, o.name, count(r.id) zeilen, round(sum((r.menge_ausdruck->>'lit')::numeric * ar.vp_knecht)) chf
from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id join offertentyp ot on ot.id = a.offertentyp_id
join ressourcenzeile r on r.option_id = o.id join artikel ar on ar.id = r.artikel_id
where o.name in ('Wasserspiel Naturteich', 'Wasserspiel Chemiepool', 'Badu Alpha 6') group by ot.name, o.name order by 1, 2;
