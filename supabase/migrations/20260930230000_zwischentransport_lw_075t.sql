-- Zwischentransport Lieferwagen: 0.75 t je Fahrt (statt 1 t). Fahrten = Gewicht / 0.75, je Fahrt Hin- und Rückstrecke.
do $$
declare ot uuid; t_gew uuid; o uuid; n int;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into t_gew from term where offertentyp_id = ot and name = 'Gewicht Natursteinmauer';
  select o.id into o from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id where f.name = 'Transport Natursteine' and o.name = 'Lieferwagen ab Lager';
  if t_gew is null or o is null then raise exception 'Option nicht gefunden'; end if;
  update ressourcenzeile set menge_ausdruck = jsonb_build_object('op', '*', 'args', jsonb_build_array(
      jsonb_build_object('op', '/', 'args', jsonb_build_array(jsonb_build_object('id', t_gew, 'ref', 'term'), jsonb_build_object('lit', 0.75))),
      jsonb_build_object('lit', 2)))
   where option_id = o;
  get diagnostics n = row_count;
  if n <> 2 then raise exception 'Erwartet 2 Zeilen, geaendert %', n; end if;
end $$;
