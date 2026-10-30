-- Mauern > Fundation: neue Option "Beton LKW" (ungepumpt), Kopie von "Beton LKW gepumpt" mit Aenderungen:
-- ohne Betonpumpe (Staffelgruppe), Pump-Schmiermischung und Restbeton-/Reinigungswasserentsorgung,
-- Beton = Magerbeton/Normalbeton 250 kg/m3, 0-16 mm (wie bei "Beton Lieferwagen") statt SVB Beton,
-- dafuer Raupendumper M: 2 Std. pro 8 m3 = 0.25 Std. pro m3 (zum Abladen/Verteilen ab LKW).
do $$
declare
  gepumpt uuid; liefer uuid; neu uuid := gen_random_uuid();
  magerbeton uuid; dumper uuid; j jsonb; r record; rf int := 0; n int;
begin
  select ao.id into gepumpt from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
    join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Mauern' and s.name = 'Fundation' and ao.name = 'Beton LKW gepumpt';
  select ao.id into liefer from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
    join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Mauern' and s.name = 'Fundation' and ao.name = 'Beton Lieferwagen';
  if gepumpt is null or liefer is null then raise exception 'Optionen Beton LKW gepumpt / Beton Lieferwagen nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = (select auswahlfeld_id from auswahloption where id = gepumpt) and name = 'Beton LKW') then
    raise exception 'Option Beton LKW existiert schon';
  end if;

  select id into magerbeton from artikel where bezeichnung = 'Magerbeton / Normalbeton, 250 kg/m3, 0–16 mm' limit 1;
  select id into dumper from artikel where artikelnummer_knecht = 'KNECHT_000114';
  if magerbeton is null or dumper is null then raise exception 'Artikel Magerbeton 250 0-16 oder Raupendumper M nicht gefunden'; end if;

  -- Reihenfolge: neue Option steht zwischen "Beton LKW gepumpt" (3) und "Beton Lieferwagen" (4 -> 5)
  update auswahloption set reihenfolge = reihenfolge + 1
   where auswahlfeld_id = (select auswahlfeld_id from auswahloption where id = gepumpt) and reihenfolge >= 4;

  select to_jsonb(o) into j from auswahloption o where o.id = gepumpt;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', neu, 'name', 'Beton LKW', 'reihenfolge', 4,
      'beschreibung', 'Fundament mit Beton ab LKW erstellen.'));

  -- Zeilen von "Beton LKW gepumpt" uebernehmen, ausser Betonpumpe (Staffelgruppe), Pump-Schmiermischung, Restbeton
  for r in
    select rz.*, a.bezeichnung as art_bez from ressourcenzeile rz left join artikel a on a.id = rz.artikel_id
     where rz.option_id = gepumpt order by rz.reihenfolge
  loop
    if r.staffelgruppe_id is not null then continue; end if;                                   -- Betonpumpe
    if r.art_bez like 'Pump-Schmiermischung%' or r.art_bez like 'Restbeton-%' then continue; end if;
    rf := rf + 1;
    j := to_jsonb(r) - 'art_bez';
    j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu, 'reihenfolge', rf);
    if r.art_bez = 'SVB Beton' then j := j || jsonb_build_object('artikel_id', magerbeton); end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
    if r.art_bez = 'SVB Beton' then
      -- Raupendumper M direkt nach dem Beton: 0.25 Std. pro m3 (8 m3 = 2 Std.)
      rf := rf + 1;
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
        j || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', rf, 'kategorie', 'maschine', 'artikel_id', dumper,
          'menge_ausdruck', '{"lit": 0.25, "_einheit": "Std."}'::jsonb, 'verschnitt_prozent', null, 'mindestmenge', null,
          'mengenoption_ausgenommen', false, 'notiz', 'Abladen/Verteilen ab LKW: 2 Std. pro 8 m³ = 0.25 Std. pro m³'));
    end if;
  end loop;

  select count(*) into n from ressourcenzeile where option_id = neu;
  if n <> 6 then raise exception 'Beton LKW: erwartet 6 Zeilen, angelegt %', n; end if;
end $$;
