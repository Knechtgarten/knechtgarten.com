-- Pool: COFFRA Schalungsstein auch bei "Treppe betonieren" (2 m2 pauschal) und "Sitzbank betonieren"
-- (1 m2 je Laufmeter Sitzbank = 1 m hoch, Menge wird ueber die Mengenoption mit den Laufmetern multipliziert).
-- Beide mit 10 % Verschnitt wie bei den Poolwaenden. Zeile steht nach dem Armierungsstahl.
do $$
declare
  coffra uuid; j jsonb; n int; opt uuid;
  treppe uuid := 'b2840b9a-b2ff-48bb-9aa7-979a17254309';
  sitzbank uuid := '187e554c-0419-4822-b00e-57e9f1f6d62d';
begin
  select id into coffra from artikel where bezeichnung = 'COFFRA Schalungsstein' limit 1;
  if coffra is null then raise exception 'Artikel COFFRA Schalungsstein nicht gefunden'; end if;

  -- Treppe: Zeilen 1-4, 6-9 (8 Stueck), Armierungsstahl = 8, Maschinen = 9 -> neue Zeile 9
  opt := treppe;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 8 then raise exception 'Treppe: erwartet 8 Zeilen, gefunden %', n; end if;
  if exists (select 1 from ressourcenzeile where option_id = opt and artikel_id = coffra) then raise exception 'Treppe: Stein schon vorhanden'; end if;
  update ressourcenzeile set reihenfolge = reihenfolge + 1 where option_id = opt and reihenfolge >= 9;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.option_id = opt and rz.reihenfolge = 8;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    j || jsonb_build_object('id', gen_random_uuid(), 'artikel_id', coffra, 'reihenfolge', 9,
      'menge_ausdruck', '{"lit": 2, "_einheit": "m²"}'::jsonb, 'verschnitt_prozent', 10, 'notiz', null));

  -- Sitzbank: 8 Zeilen, Armierungsstahl = 5 -> neue Zeile 6
  opt := sitzbank;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 8 then raise exception 'Sitzbank: erwartet 8 Zeilen, gefunden %', n; end if;
  if exists (select 1 from ressourcenzeile where option_id = opt and artikel_id = coffra) then raise exception 'Sitzbank: Stein schon vorhanden'; end if;
  update ressourcenzeile set reihenfolge = reihenfolge + 1 where option_id = opt and reihenfolge >= 6;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.option_id = opt and rz.reihenfolge = 5;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    j || jsonb_build_object('id', gen_random_uuid(), 'artikel_id', coffra, 'reihenfolge', 6,
      'menge_ausdruck', '{"lit": 1, "_einheit": "m²"}'::jsonb, 'verschnitt_prozent', 10, 'notiz', null));
end $$;
