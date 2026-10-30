-- Beläge > Randbefestigung: zwei neue Optionen "Stahlblech 150 mm" und "Stahlblech 300 mm" (Mengenoption in Laufmetern)
-- Pro Laufmeter: Breitflachstahl roh (150x5 mm Stange 6 m = 1/6 Stange, 300x6 mm Stange 3 m = 1/3 Stange, Mindestmenge 6 m),
-- Armierungsstahl 8-10 mm als Anker (alle 70 cm ein Eisen, 60 cm lang = 0.6/0.7 m), Polier + Gartenarbeiter je 0.25 Std.
-- (= 1.5 Std. pro 6-m-Stange), Maschinen und Geräte Bau 0.1 Std.
-- Die Optionen stehen nach "Fassadenprofil", vor der Gruppe "Abschluss Pflästerstein".
do $$
declare
  af_id uuid; vorlage uuid; geraete uuid; armierung uuid; polier uuid; garten uuid;
  j jsonb; jz jsonb; o record; r record; opt uuid; n int;
begin
  select ao.id, ao.auswahlfeld_id into vorlage, af_id
    from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
    join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Beläge, Hartflächen' and af.name = 'Randbefestigung' and ao.name = 'Fassadenprofil';
  if vorlage is null then raise exception 'Option Fassadenprofil nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name like 'Stahlblech%') then raise exception 'Stahlblech-Optionen existieren schon'; end if;

  select id into geraete from artikel where artikelnummer_knecht = 'KNECHT_000131';
  select id into armierung from artikel where artikelnummer_knecht = 'KNECHT_000430';
  select artikel_id into polier from ressourcenzeile where option_id = vorlage and kategorie = 'personal' order by reihenfolge limit 1;
  select artikel_id into garten from ressourcenzeile where option_id = vorlage and kategorie = 'personal' order by reihenfolge offset 1 limit 1;
  if geraete is null or armierung is null or polier is null or garten is null then raise exception 'Artikel fehlen'; end if;

  -- Platz schaffen: Gruppe und alles dahinter um 2 nach hinten (Fassadenprofil hat Reihenfolge 3)
  update auswahloption set reihenfolge = reihenfolge + 2
   where auswahlfeld_id = af_id and reihenfolge > (select reihenfolge from auswahloption where id = vorlage);

  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = vorlage and rz.kategorie = 'material' order by rz.reihenfolge limit 1;

  for o in select * from (values
      (1, 'Stahlblech 150 mm', 'f7755021-ae79-414c-bbc4-88c0580733fc'::uuid, 6, 1,
          'Randabschluss mit Stahlblech 150 × 5 mm (Breitflachstahl roh), mit Armierungseisen verankert, liefern und montieren.',
          E'Menge in Laufmetern. Breitflachstahl 150 × 5 mm, Stangen à 6 m, Anker alle 70 cm.'),
      (2, 'Stahlblech 300 mm', 'b0f2b198-a3fc-464d-9714-29cfcd37a651'::uuid, 3, 2,
          'Randabschluss mit Stahlblech 300 × 6 mm (Breitflachstahl roh), mit Armierungseisen verankert, liefern und montieren.',
          E'Menge in Laufmetern. Breitflachstahl 300 × 6 mm, Stangen à 3 m, Anker alle 70 cm.')
    ) as v(rf, nm, stahl, stangenlaenge, minstangen, bes, hinw)
  loop
    opt := gen_random_uuid();
    select to_jsonb(x) into j from auswahloption x where x.id = vorlage;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
      j || jsonb_build_object('id', opt, 'name', o.nm, 'reihenfolge', 3 + o.rf, 'beschreibung', o.bes, 'hinweistext', o.hinw,
        'mengenoption', true, 'mengenoption_einheit', 'm', 'mengenoption_standardmenge', null, 'mehrfachauswahl', false,
        'optionsgruppe_id', null, 'optionsgruppe_name', null, 'ist_standard', false));

    for r in select * from (values
        (1, 'personal', polier,    '{"lit": 0.25, "_einheit": "Std."}'::jsonb, null::numeric, 'Einbau: 1.5 Std. pro 6-m-Stange = 0.25 Std. pro Laufmeter'),
        (2, 'personal', garten,    '{"lit": 0.25, "_einheit": "Std."}'::jsonb, null::numeric, 'Einbau: 1.5 Std. pro 6-m-Stange = 0.25 Std. pro Laufmeter'),
        (3, 'material', o.stahl,   jsonb_build_object('op', '/', 'args', jsonb_build_array(jsonb_build_object('lit', 1, '_einheit', 'm'), jsonb_build_object('lit', o.stangenlaenge, '_einheit', 'm'))), o.minstangen::numeric, 'Stangen: 1 / Stangenlänge pro Laufmeter, Mindestmenge 6 m'),
        (4, 'material', armierung, jsonb_build_object('op', '/', 'args', jsonb_build_array(jsonb_build_object('lit', 0.6, '_einheit', 'm'), jsonb_build_object('lit', 0.7, '_einheit', 'm'))), null::numeric, 'Anker: alle 70 cm ein Eisen à 60 cm = 0.6 / 0.7 m pro Laufmeter'),
        (5, 'maschine', geraete,   '{"lit": 0.1, "_einheit": "Std."}'::jsonb, null::numeric, 'Trennscheibe/Schweissgerät, 0.1 Std. pro Laufmeter')
      ) as v(rf, kat, art, menge, mind, notiz)
    loop
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
        jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat, 'artikel_id', r.art,
          'menge_ausdruck', r.menge, 'mindestmenge', r.mind, 'notiz', r.notiz,
          'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
          'verschnitt_prozent', null, 'zuschlag_prozent', null, 'preis_override', null, 'bezeichnung_override', null,
          'staffelgruppe_id', null, 'zonengruppe_id', null, 'auswahlgruppe_id', null, 'sonderposition_typ_id', null,
          'tagesleistung_menge', null, 'ist_eigene_offertenposition', false, 'mengenoption_ausgenommen', false));
    end loop;
  end loop;

  select count(*) into n from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id where ao.auswahlfeld_id = af_id and ao.name like 'Stahlblech%';
  if n <> 10 then raise exception 'Erwartet 10 Zeilen, angelegt %', n; end if;
end $$;
