-- Naturteich/Schwimmteich > Betonplatte Tiefenzone: drei Varianten (gepumpt, LKW ungepumpt, Lieferwagen) und
-- "Zusatz: Magerbeton-Schicht" (Sauberkeitsschicht, wählbar statt fest in der Platte).
--  gepumpt:       bisherige Platte ohne Magerbeton (SVB-Beton, Betonpumpe, Schmiermischung, Restbeton)
--  LKW:           Normalbeton 250 ab LKW (ungepumpt) + Raupendumper M 0.25 Std. je m3 (mind. 1 Std.), ohne Pumpe/Schmiermischung/Restbeton
--  Lieferwagen:   Normalbeton 250 per Lieferwagen (4 Fahrten je m3, wie bei den Mauern), ohne Pumpe/Schmiermischung/Restbeton/LKW-Transport
-- Alle drei behalten Personal, Folie, Armierung, Distanzhalter, Hilfsmaterial und Geräte.
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;

create or replace function pg_temp.kopiere_platte(src uuid, af uuid, nm text, rf int, bes text, mehrfach boolean, ausschliessen int[], ersatz_artikel_von uuid, ersatz_artikel_nach uuid) returns uuid language plpgsql as $$
declare neu uuid := gen_random_uuid(); j jsonb; r record; jr jsonb;
begin
  select to_jsonb(o) into j from auswahloption o where o.id = src;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', neu, 'auswahlfeld_id', af, 'name', nm, 'reihenfolge', rf, 'beschreibung', bes, 'mehrfachauswahl', mehrfach, 'optionsgruppe_id', null, 'optionsgruppe_name', null));
  for r in select * from ressourcenzeile where option_id = src order by reihenfolge loop
    if r.reihenfolge = any(ausschliessen) then continue; end if;
    jr := to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu);
    if ersatz_artikel_von is not null and r.artikel_id = ersatz_artikel_von then jr := jr || jsonb_build_object('artikel_id', ersatz_artikel_nach); end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jr);
  end loop;
  return neu;
end $$;

do $$
declare
  ot uuid; af uuid; pa uuid; as_id uuid; f_beton uuid; svb uuid; normal uuid; dumper uuid; opt uuid; zusatz uuid;
  lw_src uuid; r record; jr jsonb; mager_menge jsonb; n int;
begin
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select s.id into as_id from arbeitsschritt s where s.offertentyp_id = ot and s.name = 'Betonplatte Tiefenzone';
  select ao.id, ao.auswahlfeld_id into pa, af from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id where t.arbeitsschritt_id = as_id and ao.name = 'Bodenplatte armiert';
  select id into f_beton from term where offertentyp_id = ot and name = 'Beton Platte Tiefenzone';
  select artikel_id into svb from ressourcenzeile where option_id = pa and reihenfolge = 5;
  select id into normal from artikel where bezeichnung = 'Magerbeton / Normalbeton, 250 kg/m3, 0–16 mm' limit 1;
  select id into dumper from artikel where artikelnummer_knecht = 'KNECHT_000114';
  select ao.id into lw_src from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id join offertentyp o on o.id = s.offertentyp_id
   where o.name = 'Mauern' and s.name = 'Fundation' and ao.name = 'Beton Lieferwagen';
  if ot is null or pa is null or f_beton is null or svb is null or normal is null or dumper is null or lw_src is null then raise exception 'Grundlagen nicht gefunden'; end if;
  select menge_ausdruck into mager_menge from ressourcenzeile where option_id = pa and reihenfolge = 9;

  -- Zusatz: Magerbeton-Schicht (Zeilen 8 = Beton-Transport, 9 = Magerbeton aus der bisherigen Platte)
  zusatz := pg_temp.kopiere_platte(pa, af, 'Zusatz: Magerbeton-Schicht', 4, 'Magerbeton-Schicht als Sauberkeitsschicht unter der Platte einbringen.', true, array[1,2,3,4,5,6,7,10,11,12,13,14], null, null);
  update ressourcenzeile set menge_ausdruck = mager_menge where option_id = zusatz and reihenfolge = 8;
  update auswahloption set hinweistext = 'Dicke der Schicht: Wert «Dicke Magerbeton» (Formeln), Fläche = Plattenfläche.' where id = zusatz;

  -- LKW (ungepumpt)
  opt := pg_temp.kopiere_platte(pa, af, 'Bodenplatte LKW', 2, 'Betonplatte für die Tiefenzone mit Armierung erstellen, Beton ab LKW (ungepumpt).', false, array[3,6,7,8,9], svb, normal);
  select to_jsonb(rz) into jr from ressourcenzeile rz where rz.option_id = opt and rz.reihenfolge = 5;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jr || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', 15, 'kategorie', 'maschine', 'artikel_id', dumper,
    'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(f_beton), jsonb_build_object('lit', 0.25, '_einheit', 'Std.')), 'mindestmenge', 1, 'notiz', 'Abladen/Verteilen ab LKW: 0.25 Std. je m³'));

  -- Lieferwagen
  opt := pg_temp.kopiere_platte(pa, af, 'Bodenplatte Lieferwagen', 3, 'Betonplatte für die Tiefenzone mit Armierung erstellen, Beton per Lieferwagen angeliefert.', false, array[3,4,6,7,8,9], svb, normal);
  for r in select * from ressourcenzeile where option_id = lw_src and reihenfolge in (4, 5) order by reihenfolge loop
    jr := to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 15 + r.reihenfolge,
      'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(f_beton), jsonb_build_object('lit', 4)), 'notiz', '4 Fahrten je m³ Beton');
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jr);
  end loop;

  -- gepumpt: bisherige Option umbenennen und Magerbeton-Teile (Zeilen 8 und 9) entfernen
  delete from ressourcenzeile where option_id = pa and reihenfolge in (8, 9);
  update auswahloption set name = 'Bodenplatte gepumpt', reihenfolge = 1, beschreibung = 'Betonplatte für die Tiefenzone mit Armierung erstellen, Beton gepumpt.' where id = pa;

  select count(*) into n from auswahloption where auswahlfeld_id = af;
  if n <> 4 then raise exception 'Erwartet 4 Optionen, gefunden %', n; end if;
end $$;
