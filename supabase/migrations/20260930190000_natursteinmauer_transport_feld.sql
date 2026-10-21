-- Natursteinmauer: Transport der Steine als eigene Auswahl (nur einer wählbar):
--   Direkt (gekippt) | Mulde LKW ab Lager | Lieferwagen ab Lager
-- "Transport gekippt" ist nicht mehr fest in den Mauer-Buttons, sondern die Option "Direkt (gekippt)".
do $$
declare
  ot uuid; as_nat uuid; af_t uuid; ts_t uuid; o_mulde uuid; o_lw uuid; o_dir uuid := gen_random_uuid(); src uuid; n int; a_t uuid; j jsonb; tmpl jsonb;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_nat from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer';
  select ts.id, af.id into ts_t, af_t from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id where ts.arbeitsschritt_id = as_nat and ts.name = 'Zwischentransport Natursteine';
  select id into o_mulde from auswahloption where auswahlfeld_id = af_t and name = 'Mulde LKW';
  select id into o_lw from auswahloption where auswahlfeld_id = af_t and name = 'Lieferwagen ab Lager';
  select id into a_t from artikel where bezeichnung = 'Transport Natursteine gekippt (Plasselb)';
  if ts_t is null or o_mulde is null or o_lw is null or a_t is null then raise exception 'Zwischentransport nicht gefunden'; end if;

  -- Transportzeile von einer Mauer-Option als Vorlage nehmen, dann aus allen Mauer-Optionen entfernen
  select rz.id into src from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id
   where ts.arbeitsschritt_id = as_nat and ts.name <> 'Zwischentransport Natursteine' and rz.artikel_id = a_t and o.name = 'von Hand';
  if src is null then raise exception 'Transportzeile nicht gefunden'; end if;
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_mulde;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', o_dir, 'name', 'Direkt (gekippt)', 'reihenfolge', 1,
      'beschreibung', 'Natursteine direkt ab Plasselb auf die Baustelle liefern (gekippt).'));
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = src;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j || jsonb_build_object('id', gen_random_uuid(), 'option_id', o_dir, 'teilschritt_id', null, 'reihenfolge', 1));
  delete from ressourcenzeile rz using auswahloption o, auswahlfeld f, teilschritt ts
   where rz.option_id = o.id and f.id = o.auswahlfeld_id and ts.id = f.teilschritt_id
     and ts.arbeitsschritt_id = as_nat and ts.name <> 'Zwischentransport Natursteine' and rz.artikel_id = a_t;
  get diagnostics n = row_count;

  update auswahloption set name = 'Mulde LKW ab Lager', reihenfolge = 2 where id = o_mulde;
  update auswahloption set reihenfolge = 3 where id = o_lw;
  update teilschritt set name = 'Transport Natursteine' where id = ts_t;
  update auswahlfeld set name = 'Transport Natursteine' where id = af_t;
  raise notice 'Transportzeilen aus Mauer-Optionen entfernt: %', n;
end $$;
