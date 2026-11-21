-- Naturteich/Schwimmteich: Bepflanzung (Stefan 2026-11-21)
-- Artikel: Seerose CHF 60, Iris sibirica 8.50, Zyperngras 10.90 (Baumschule Däpp, MwSt reduziert),
--          Wasserpflanzen Budget CHF 70 pro m² (wie Stauden), Spezial-Pflanzkissen CHF 150 (Annahme, Preis noch nicht bekannt).
-- Arbeitsschritt «Bepflanzung» mit Wasserpflanzen-Fläche (m²), Seerosen (Stk.), Pflanzkissen (Stk.) inkl. Pflanzzeit.
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht, waehrung, mwst_art, preis_gesperrt, sync_offertentool)
select v.lief::uuid, 'material', v.lnr, v.nr, v.bez, v.eh, v.vp, 'CHF', v.mwst, true, true
from (values
  ('7c6aa66d-0be2-406d-9a73-e967019c2077', 'Seerose', 'DAEPP_SEEROSE', 'Seerose (Nymphaea) im Topf', 'Stk.', 60::numeric, 'reduziert'),
  ('7c6aa66d-0be2-406d-9a73-e967019c2077', 'Iris-sibirica', 'DAEPP_IRIS-SIBIRICA', 'Iris sibirica (Sibirische Schwertlilie)', 'Stk.', 8.50, 'reduziert'),
  ('7c6aa66d-0be2-406d-9a73-e967019c2077', 'Cyperus', 'DAEPP_CYPERUS', 'Cyperus (Zyperngras)', 'Stk.', 10.90, 'reduziert'),
  ('7c6aa66d-0be2-406d-9a73-e967019c2077', 'Wasserpflanzen-m2', 'DAEPP_WASSERPFLANZEN_M2', 'Budgetbetrag für Wasserpflanzen pro m²', 'Budg', 70, 'reduziert'),
  ('db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'PFLANZKISSEN', 'KNECHT_PFLANZKISSEN', 'Spezial-Pflanzkissen für Wasserpflanzen', 'Stk.', 150, 'normal')
) v(lief, lnr, nr, bez, eh, vp, mwst)
where not exists (select 1 from artikel a where a.artikelnummer_knecht = v.nr);

do $$
declare
  ot uuid := 'bcc55d19-7e61-4fc8-80d0-0889c3148896'; a uuid; t uuid; f uuid; o uuid; v record;
begin
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Bepflanzung') then return; end if;
  insert into arbeitsschritt (offertentyp_id, name, reihenfolge) values (ot, 'Bepflanzung', (select max(reihenfolge) + 1 from arbeitsschritt where offertentyp_id = ot)) returning id into a;
  insert into teilschritt (arbeitsschritt_id, name, reihenfolge) values (a, 'Wasserpflanzen', 1) returning id into t;
  insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (t, 'Wasserpflanzen', 1) returning id into f;
  for v in select * from (values
    (1, 'Wasserpflanzen-Fläche', 'm²', 'Wasserpflanzen liefern und pflanzen (Budget pro m² Pflanzfläche).', 'Fläche der Pflanzzone eintragen (ohne Bereiche mit Mauer). Budget CHF 70 pro m².', 'DAEPP_WASSERPFLANZEN_M2', 0.3),
    (2, 'Seerosen', 'Stk.', 'Seerosen liefern und pflanzen.', 'CHF 60 pro Seerose.', 'DAEPP_SEEROSE', 0.25),
    (3, 'Pflanzkissen', 'Stk.', 'Spezial-Pflanzkissen für Wasserpflanzen liefern und einbauen.', 'CHF 150 pro Kissen (Annahme).', 'KNECHT_PFLANZKISSEN', 0.5)
  ) x(rf, name, eh, beschr, hinweis, nr, std) loop
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
    values (f, v.name, v.rf, v.beschr, v.hinweis, false, true, v.eh, true, false) returning id into o;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o, 'material', (select id from artikel where artikelnummer_knecht = v.nr), '{"lit": 1}', 'baukasten', 1, 1, 1, 1, 1),
      (o, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81', jsonb_build_object('lit', v.std, '_einheit', 'Std.'), 'baukasten', 1, 1, 1, 1, 2);
  end loop;
end $$;
