-- Nachtrag Blendmauer "Betonmauer mit Lieferwagen": Lieferwagenchauffeur und
-- Lieferwagentransport Kieswerk/Betonwerk (aus "Fundation Kieseinbau Lieferwagen"),
-- Menge = Beton total / 0.5 m3 pro Fahrt x 2 (hin und zurueck) = Beton x 4.
do $$
declare
  ot uuid; opt_lw uuid; t_beton uuid; rec record; j jsonb; rr int; n int := 0;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select o.id into opt_lw from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
    join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and o.name = 'Betonmauer mit Lieferwagen';
  select t.id into t_beton from term t where t.offertentyp_id = ot and t.name like 'Beton Blendmauer total%';
  if opt_lw is null or t_beton is null then raise exception 'Option oder Term nicht gefunden'; end if;
  if exists (select 1 from ressourcenzeile where option_id = opt_lw and sonderposition_typ_id is not null) then
    raise exception 'Fahrten-Zeilen sind schon vorhanden - nichts geaendert.';
  end if;
  select coalesce(max(reihenfolge), 0) into rr from ressourcenzeile where option_id = opt_lw;
  for rec in
    select rz.* from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld af on af.id = o.auswahlfeld_id
      join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
     where a.offertentyp_id = ot and o.name = 'Fundation Kieseinbau Lieferwagen' and rz.sonderposition_typ_id is not null
     order by rz.reihenfolge
  loop
    rr := rr + 1; n := n + 1;
    j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_lw, 'teilschritt_id', null, 'reihenfolge', rr,
          'menge_ausdruck', jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('id', t_beton, 'ref', 'term'), jsonb_build_object('lit', 4))));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
  end loop;
  if n <> 2 then raise exception 'Erwartet 2 Fahrten-Zeilen, gefunden % - nichts geaendert.', n; end if;
end $$;
