-- Pool "Waende betonieren": COFFRA Schalungsstein ergaenzen (wie bei Verblendmauer/Coffra):
-- Menge = Flaeche Poolwaende, 10 % Verschnitt. Steht nach Armierungsstahl, Kranwagen/Maschinen rutschen nach hinten.
do $$
declare
  opt uuid := '6b1a1029-c4d0-4d8a-9f84-4ab30db7b73c';   -- Pool/Wassergarten > Beckenkoerper Beton > Waende betonieren
  coffra uuid; j jsonb; n int;
begin
  select id into coffra from artikel where bezeichnung = 'COFFRA Schalungsstein' limit 1;
  if coffra is null then raise exception 'Artikel COFFRA Schalungsstein nicht gefunden'; end if;
  if exists (select 1 from ressourcenzeile where option_id = opt and artikel_id = coffra) then
    raise exception 'COFFRA Schalungsstein ist bei dieser Option schon vorhanden';
  end if;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 12 then raise exception 'Erwartet 12 Zeilen, gefunden %', n; end if;

  update ressourcenzeile set reihenfolge = reihenfolge + 1 where option_id = opt and reihenfolge >= 11;

  select to_jsonb(rz) into j from ressourcenzeile rz where rz.option_id = opt and rz.reihenfolge = 10;   -- Armierungsstahl als Zeilenvorlage
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    j || jsonb_build_object('id', gen_random_uuid(), 'artikel_id', coffra, 'reihenfolge', 11,
      'menge_ausdruck', '{"id": "bff364d7-0ec3-423a-9443-499909937aa4", "ref": "term"}'::jsonb,
      'verschnitt_prozent', 10, 'notiz', null));
end $$;
