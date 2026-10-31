-- Pooloptionen > Wärmepumpe: Wandkonsolen (Aquasolar, Paar) aus den fünf Wärmepumpen in die neue Zusatzoption
-- "Zusatz: Wandmontage Wärmepumpe" verschoben (Alternative zum Fundament). Dazu Polier + Gartenarbeiter je 1.5 Std.
do $$
declare
  af_id uuid; fundament uuid; wp30 uuid; opt uuid := gen_random_uuid(); konsole uuid; jz jsonb; j jsonb; r record; n int;
begin
  select id into konsole from artikel where id = 'a609b178-878f-48ab-8b0b-a73dd49a2319' and bezeichnung = 'Wandkonsolen zu Wärmepumpe pro Paar';
  select ao.auswahlfeld_id, ao.id into af_id, wp30 from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Wärmepumpe (ohne Grabarbeiten)' and ao.name = 'WP-30m3';
  select id into fundament from auswahloption where auswahlfeld_id = af_id and name = 'Zusatz: Fundament Wärmepumpe';
  if konsole is null or af_id is null or fundament is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name = 'Zusatz: Wandmontage Wärmepumpe') then raise exception 'Wandmontage existiert schon'; end if;

  -- Konsolen aus den Wärmepumpen entfernen
  delete from ressourcenzeile rz using auswahloption ao
   where ao.id = rz.option_id and ao.auswahlfeld_id = af_id and ao.name like 'WP-%m3' and rz.artikel_id = konsole;
  get diagnostics n = row_count;
  if n <> 5 then raise exception 'Erwartet 5 Konsolen-Zeilen, gelöscht %', n; end if;
  update auswahloption set hinweistext = replace(hinweistext, E'Inkl. Wandkonsolen\n', '')
   where auswahlfeld_id = af_id and name like 'WP-%m3';

  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = fundament and rz.reihenfolge = 1;
  select to_jsonb(x) into j from auswahloption x where x.id = fundament;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'name', 'Zusatz: Wandmontage Wärmepumpe', 'reihenfolge', 9,
      'beschreibung', 'Wärmepumpe an der Wand montieren: Wandkonsolen liefern und montieren.',
      'hinweistext', 'Inkl. Wandkonsolen (1 Paar). Alternative zum Fundament.'));
  for r in select * from (values
      (1, 'personal', (select id from artikel where artikelnummer_knecht = 'KNECHT_000015'), 1.5, 'Std.'),
      (2, 'personal', (select id from artikel where artikelnummer_knecht = 'KNECHT_000005'), 1.5, 'Std.'),
      (3, 'material', konsole, 1, 'Stk.')
    ) as v(rf, kat, art, menge, einh)
  loop
    if r.art is null then raise exception 'Artikel für Zeile % nicht gefunden', r.rf; end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat, 'artikel_id', r.art,
        'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh), 'notiz', null));
  end loop;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 3 then raise exception 'Erwartet 3 Zeilen, angelegt %', n; end if;
end $$;
