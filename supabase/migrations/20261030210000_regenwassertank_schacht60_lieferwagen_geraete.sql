-- Regenwassertank:
-- 1) Schlammsammler: Betonrohr Ø60 H105 statt Ø50, eigene Lieferwagen-Zeile (1 Std., Aushubfahrt), Maschinen und Geraete Bau 1 Std.
-- 2) Alle 18 Tank-Optionen: Maschinen und Geraete Bau 1 Std. (Verdichten)
do $$
declare
  geraete uuid; lieferwagen uuid := '773ea52c-673e-41ec-b52a-26156a1bb324';
  rohr60 uuid := 'db96a4b9-3e13-45fe-b037-9c36f500eaa5'; rohr50 uuid := '6636363a-ffe7-4b36-8741-baaf070fa917';
  o record; jz jsonb; mx int; n int;
begin
  select id into geraete from artikel where artikelnummer_knecht = 'KNECHT_000131';
  if geraete is null then raise exception 'Artikel KNECHT_000131 nicht gefunden'; end if;

  -- 1) Schlammsammler
  for o in select ao.id from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
            where af.name = 'Schlammsammler montieren' and ao.optionsgruppe_name = 'Schlammsammler'
  loop
    update ressourcenzeile set artikel_id = rohr60 where option_id = o.id and artikel_id = rohr50;
    update ressourcenzeile set reihenfolge = 8 where option_id = o.id and reihenfolge = 7;      -- Bagger nach hinten
    select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = o.id and rz.reihenfolge = 6;   -- Deponie als Zeilenvorlage
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', 7, 'kategorie', 'logistik', 'artikel_id', lieferwagen,
        'menge_ausdruck', '{"lit": 1, "_einheit": "Std."}'::jsonb));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', 9, 'kategorie', 'maschine', 'artikel_id', geraete,
        'menge_ausdruck', '{"lit": 1, "_einheit": "Std."}'::jsonb));
  end loop;
  select count(*) into n from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id join auswahlfeld af on af.id = ao.auswahlfeld_id
   where af.name = 'Schlammsammler montieren' and rz.artikel_id = rohr60;
  if n <> 3 then raise exception 'Schlammsammler: Betonrohr Ø60 bei % statt 3 Optionen', n; end if;

  -- 2) Tanks
  n := 0;
  for o in select ao.id from auswahloption ao where ao.auswahlfeld_id = 'a261ca94-c416-4148-bd2c-fecbe2aaf8cb'
  loop
    select max(reihenfolge) into mx from ressourcenzeile where option_id = o.id;
    select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = o.id and rz.kategorie = 'material' order by rz.reihenfolge limit 1;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', mx + 1, 'kategorie', 'maschine', 'artikel_id', geraete,
        'menge_ausdruck', '{"lit": 1, "_einheit": "Std."}'::jsonb, 'menge_formel_baukasten_ausdruck', null, 'menge_formel_text', null,
        'bezeichnung_override', null, 'preis_override', null, 'notiz', null, 'mindestmenge', null, 'verschnitt_prozent', null, 'zuschlag_prozent', null));
    n := n + 1;
  end loop;
  if n <> 18 then raise exception 'Tanks: erwartet 18 Optionen, bearbeitet %', n; end if;
end $$;
