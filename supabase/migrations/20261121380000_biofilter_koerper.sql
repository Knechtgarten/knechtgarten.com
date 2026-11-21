-- Biofilter-Körper und Brienzer Kies (Stefan 2026-11-21)
--  1 «+ Brienzer Kies» (Pool › Wasseraufbereitung Bio, Teich › Biofilter): fix 0.5 m³, keine m²-Eingabe mehr
--  2 Pool › Beckenkörper Beton: Gruppe «Biofilter-Mauer» mit «längs» / «quer» (Zwischenmauer innerhalb des Poolmasses,
--    Höhe = Tiefe − 0.2 m für den Überlauf), Zeilen wie «Wände betonieren» pro m² Mauerfläche
--  3 Edelstahlbehälter: separat (Migration Grütter-Biofilter)
--  4 Hinweis bei Länge/Breite innen: inkl. Biofilter (PP-Becken: Zwischenmauer rechnet der Beckenbauer)

-- 1 Brienzer Kies fix 0.5 m³
do $$
declare o record;
begin
  for o in select ao.id from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id
           where ao.name = '+ Brienzer Kies' and t.name in ('Wasseraufbereitung Bio', 'Biofilter') loop
    update auswahloption set mengenoption = false,
      beschreibung = 'Biofilter mit Brienzer Kies abstreuen.',
      hinweistext = 'Fix 0.5 m³ Brienzer Kies ab Lager (CHF 220.–/m³) inkl. Transport und Abstreuen.'
    where id = o.id;
    update ressourcenzeile r set menge_ausdruck = case
        when r.kategorie = 'material' then '{"lit": 0.5, "_einheit": "m³"}'::jsonb
        when r.kategorie = 'logistik' then '{"lit": 0.5}'::jsonb
        else '{"lit": 1.25, "_einheit": "Std."}'::jsonb end,
      notiz = case when r.kategorie = 'personal' then 'Abstreuen 0.5 m³' else r.notiz end
    where r.option_id = o.id;
  end loop;
end $$;

-- 2 Biofilter-Mauer längs / quer
do $$
declare
  feld uuid; waende uuid; gruppe uuid := gen_random_uuid(); neu uuid; v record;
  laenge constant text := '8bd9110e-f946-4cc4-b992-7c0f6e6a9b25';
  breite constant text := '2567fa39-6fce-4d16-aa31-f033aa84dad1';
  tiefe  constant text := 'aa352ddd-e412-4de2-97ce-16117858784f';
  flaeche_alt constant text := '{"id": "bff364d7-0ec3-423a-9443-499909937aa4", "ref": "term"}';
  umfang_alt  constant text := '{"id": "cb48054f-2668-400b-8bea-29789b3ecef7", "ref": "term"}';
  flaeche_neu text; laenge_neu text;
begin
  select o.id, o.auswahlfeld_id into waende, feld from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
  where a.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and t.name = 'Beckenkörper Beton' and o.name = 'Wände betonieren';
  if exists (select 1 from auswahloption where auswahlfeld_id = feld and optionsgruppe_name = 'Biofilter-Mauer') then return; end if;
  for v in select * from (values (6, 'längs', laenge, 'Biofilter längs (parallel zur Poollänge): Zwischenmauer so lang wie die Länge innen.'),
                                 (7, 'quer',  breite, 'Biofilter stirnseitig (quer): Zwischenmauer so lang wie die Breite innen. Meistens so.')) x(rf, name, mass, hinweis) loop
    laenge_neu  := jsonb_build_object('ref', 'eingabefeld', 'id', v.mass)::text;
    flaeche_neu := jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', v.mass),
                     jsonb_build_object('op', '-', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', tiefe), jsonb_build_object('lit', 0.2)))))::text;
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition, optionsgruppe_id, optionsgruppe_name)
    values (feld, v.name, v.rf, 'Zwischenmauer zwischen Pool und Biofilter mit Schalungssteinen erstellen, armieren und ausbetonieren.',
      v.hinweis || ' Höhe = Tiefe − 0.2 m (Überlauf in den Pool). Länge/Breite innen inkl. Biofilter eingeben.',
      false, false, false, false, gruppe, 'Biofilter-Mauer') returning id into neu;
    -- Zeilen von «Wände betonieren», die von der Wandfläche bzw. dem Umfang abhängen (feste Zeilen wie Kranwagen/Pumpe nicht)
    insert into ressourcenzeile
    select (jsonb_populate_record(null::ressourcenzeile, to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu,
      'menge_ausdruck', replace(replace(r.menge_ausdruck::text, flaeche_alt, flaeche_neu), umfang_alt, laenge_neu)::jsonb,
      'menge_formel_baukasten_ausdruck', null))).*
    from ressourcenzeile r where r.option_id = waende and (r.menge_ausdruck::text like '%bff364d7%' or r.menge_ausdruck::text like '%cb48054f%');
  end loop;
end $$;

-- 4 Hinweis Poolmasse
update eingabefeld set erklaerung = 'Poollänge Innenmass. Mit Biofilter: Länge inkl. Biofilter (er liegt innerhalb des Poolmasses).' where id = '8bd9110e-f946-4cc4-b992-7c0f6e6a9b25';
update eingabefeld set erklaerung = 'Poolbreite Innenmass. Mit Biofilter: Breite inkl. Biofilter (er liegt innerhalb des Poolmasses).' where id = '2567fa39-6fce-4d16-aa31-f033aa84dad1';

select o.name, o.optionsgruppe_name grp, o.mehrfachauswahl mf, o.mengenoption mo, count(r.id) zeilen, (select count(*) from option_freitext_vorlage v where v.option_id = o.id) gelb
from auswahloption o left join ressourcenzeile r on r.option_id = o.id
where o.name in ('längs', 'quer', '+ Edelstahlbehälter', '+ Brienzer Kies') group by o.id, o.name, o.optionsgruppe_name, o.mehrfachauswahl, o.mengenoption order by 1;
