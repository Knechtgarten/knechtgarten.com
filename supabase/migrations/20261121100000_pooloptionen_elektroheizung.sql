-- Pooloptionen: Arbeitsschritt «Elektroheizung» (Stefan 2026-11-21), aufgebaut wie «Wärmetauscher».
-- Optionsgruppe «Elektro-Wärmetauscher» mit 9 kW und 12 kW; je Elektro-Wärmetauscher Behncke EWT 80-70,
-- passende Steuerung (Schaltschütz), Strömungsschalter im T-Stück, Temperaturregler T-Control 1, Pauschale Hilfsmaterial.
-- Neue Aquasolar-Artikel: Listenpreise (vp_lieferant) aus dem Behncke-Katalog bzw. Shop (T-Control: UVP 588, EK 353),
-- VP Knecht rechnet der Trigger. Fotos fehlen noch (Shop nur mit Händler-Login).

insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, ep_lieferant, vp_lieferant, waehrung, mwst_art, sync_offertentool)
select 'd792a7b8-cdb5-4443-bd9d-67bdf4a6f87b', 'material', v.nr, 'AQUASOL_' || v.nr, v.bez, 'Stk.', v.ep, v.vpl, 'CHF', 'normal', true
from (values
  ('131170', 'Behncke Elektro-Wärmetauscher EWT 80-70 9 kW, 400 V, 16 A, Edelstahl V4A, Heizstab Incoloy, Regelthermostat 0–40 °C, ohne Schütz', null::numeric, 729::numeric),
  ('131168', 'Behncke Elektro-Wärmetauscher EWT 80-70 12 kW, 400 V, 20 A, Edelstahl V4A, Heizstab Incoloy, Regelthermostat 0–40 °C, ohne Schütz', null, 830),
  ('131080', 'Behncke Steuerung (Schaltschütz) für Elektroheizung 3 / 6 / 9 kW', null, 295),
  ('131081', 'Behncke Steuerung (Schaltschütz) für Elektroheizung 12 / 15 / 18 kW', null, 367),
  ('131079', 'Behncke Strömungsschalter in T-Stück d 50 mm eingebaut', null, 142),
  ('081006', 'Temperaturregler T-Control 1 inkl. Fühler mit 5 m Kabel und Tauchhülse NiSn', 353, 588)
) v(nr, bez, ep, vpl)
where not exists (select 1 from artikel a where a.artikelnummer_knecht = 'AQUASOL_' || v.nr);

-- Arbeitsschritt direkt nach «Wärmetauscher»
update arbeitsschritt set reihenfolge = reihenfolge + 1
 where offertentyp_id = '5347bac1-9562-469d-b4cd-fc9885a571f7'
   and reihenfolge > (select reihenfolge from arbeitsschritt where id = '7a142602-cee8-4758-b84c-90ec566c1669')
   and not exists (select 1 from arbeitsschritt where offertentyp_id = '5347bac1-9562-469d-b4cd-fc9885a571f7' and name = 'Elektroheizung');

with a as (
  insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
  select '5347bac1-9562-469d-b4cd-fc9885a571f7', 'Elektroheizung', reihenfolge + 1 from arbeitsschritt where id = '7a142602-cee8-4758-b84c-90ec566c1669'
    and not exists (select 1 from arbeitsschritt where offertentyp_id = '5347bac1-9562-469d-b4cd-fc9885a571f7' and name = 'Elektroheizung')
  returning id
), t as (
  insert into teilschritt (arbeitsschritt_id, name, reihenfolge) select id, 'Elektroheizung', 1 from a returning id
), f as (
  insert into auswahlfeld (teilschritt_id, name, reihenfolge) select id, 'Elektroheizung', 1 from t returning id
), g as (select gen_random_uuid() as gid), o as (
  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition, optionsgruppe_id, optionsgruppe_name)
  select f.id, v.name, v.rf, v.beschr, v.hinweis, false, false, 'Stk.', false, false, g.gid, 'Elektro-Wärmetauscher'
  from f, g, (values
    ('9 kW', 1,
     'Elektro-Wärmetauscher Behncke EWT 9 kW (Edelstahl V4A) liefern und in den Poolkreislauf einbauen, inkl. Steuerung mit Schaltschütz, Strömungsschalter und Temperaturregler T-Control mit Fühler. Elektrischer Anschluss (400 V, Absicherung 16 A) bauseits durch Elektriker.',
     'Elektro-Wärmetauscher 9 kW: für Pools bis ca. 40 m³ (Richtwert, Übergangszeit mit Abdeckung)'),
    ('12 kW', 2,
     'Elektro-Wärmetauscher Behncke EWT 12 kW (Edelstahl V4A) liefern und in den Poolkreislauf einbauen, inkl. Steuerung mit Schaltschütz, Strömungsschalter und Temperaturregler T-Control mit Fühler. Elektrischer Anschluss (400 V, Absicherung 20 A) bauseits durch Elektriker.',
     'Elektro-Wärmetauscher 12 kW: für Pools bis ca. 55 m³ (Richtwert, Übergangszeit mit Abdeckung)')
  ) v(name, rf, beschr, hinweis)
  returning id, name
)
insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge, menge_formel_modus)
select o.id, z.kat, (select id from artikel where artikelnummer_knecht = z.nr), z.menge::jsonb, 1, 1, 1, 1, z.rf, 'baukasten'
from o join (values
  ('9 kW', 'personal', 'KNECHT_000015', '{"lit": 6, "_einheit": "Std."}', 1),
  ('9 kW', 'personal', 'KNECHT_000005', '{"lit": 6, "_einheit": "Std."}', 2),
  ('9 kW', 'material', 'AQUASOL_131170', '{"lit": 1, "_einheit": "Stk."}', 3),
  ('9 kW', 'material', 'AQUASOL_131080', '{"lit": 1, "_einheit": "Stk."}', 4),
  ('9 kW', 'material', 'AQUASOL_131079', '{"lit": 1, "_einheit": "Stk."}', 5),
  ('9 kW', 'material', 'AQUASOL_081006', '{"lit": 1, "_einheit": "Stk."}', 6),
  ('9 kW', 'material', 'KNECHT_00P145', '{"lit": 1, "_einheit": "Stk."}', 7),
  ('12 kW', 'personal', 'KNECHT_000015', '{"lit": 6, "_einheit": "Std."}', 1),
  ('12 kW', 'personal', 'KNECHT_000005', '{"lit": 6, "_einheit": "Std."}', 2),
  ('12 kW', 'material', 'AQUASOL_131168', '{"lit": 1, "_einheit": "Stk."}', 3),
  ('12 kW', 'material', 'AQUASOL_131081', '{"lit": 1, "_einheit": "Stk."}', 4),
  ('12 kW', 'material', 'AQUASOL_131079', '{"lit": 1, "_einheit": "Stk."}', 5),
  ('12 kW', 'material', 'AQUASOL_081006', '{"lit": 1, "_einheit": "Stk."}', 6),
  ('12 kW', 'material', 'KNECHT_00P145', '{"lit": 1, "_einheit": "Stk."}', 7)
) as z(opt, kat, nr, menge, rf) on z.opt = o.name;

select o.name opt, r.reihenfolge, a.artikelnummer_knecht, a.vp_knecht, r.menge_ausdruck->>'lit' menge
from arbeitsschritt s join teilschritt t on t.arbeitsschritt_id = s.id join auswahlfeld f on f.teilschritt_id = t.id
join auswahloption o on o.auswahlfeld_id = f.id join ressourcenzeile r on r.option_id = o.id left join artikel a on a.id = r.artikel_id
where s.offertentyp_id = '5347bac1-9562-469d-b4cd-fc9885a571f7' and s.name = 'Elektroheizung' order by o.reihenfolge, r.reihenfolge;
