-- Natursteinmauer: Zeit- und Maschinenaufwand pro m² Sichtfläche (nicht pro Tonne);
-- Stein und Transport bleiben pro Tonne. Teilschritte: Transport | wechselschichtig | geschichtet in Blöcken.
do $$
declare
  ot uuid; as_nat uuid; ts_w uuid; af_w uuid; ts_g uuid := gen_random_uuid(); af_g uuid := gen_random_uuid(); ts_t uuid;
  t_gew uuid; t_fl uuid := gen_random_uuid(); sp_fl uuid; tmpl jsonb; a_w uuid; a_s uuid; a_t uuid; n int; ids uuid[];
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_nat from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer';
  select t.id, f.id into ts_w, af_w from teilschritt t join auswahlfeld f on f.teilschritt_id = t.id where t.arbeitsschritt_id = as_nat and t.name = 'Natursteinmauer Plasselb';
  select id into ts_t from teilschritt where arbeitsschritt_id = as_nat and name = 'Transport Natursteine';
  select id into t_gew from term where offertentyp_id = ot and name = 'Gewicht Natursteinmauer';
  select s.id into sp_fl from eingabefeld_tabelle_spalte s join eingabefeld e on e.id = s.eingabefeld_id where e.offertentyp_id = ot and e.name = 'Natursteinmauer' and s.name = 'Fläche';
  select id into a_w from artikel where bezeichnung = 'Plasselb Natursteinblöcke 50-100 L (Wechselschicht)';
  select id into a_s from artikel where bezeichnung = 'Plasselb Natursteinblöcke 300-500 L (Schichten)';
  select id into a_t from artikel where bezeichnung = 'Transport Natursteine gekippt (Plasselb)';
  if ts_w is null or ts_t is null or t_gew is null or sp_fl is null or a_w is null or a_s is null or a_t is null then raise exception 'Grundlage nicht gefunden'; end if;

  -- 1. Sichtfläche als Formel (Summe der Spalte Fläche)
  select to_jsonb(t) into tmpl from term t where t.id = t_gew;
  insert into term select * from jsonb_populate_record(null::term, tmpl || jsonb_build_object('id', t_fl, 'name', 'Sichtfläche Natursteinmauer', 'einheit', 'm²',
      'ausdruck', jsonb_build_object('id', sp_fl, 'ref', 'spalte'), 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot)));

  -- 2. Personal, Maschinen, Kran: Gewicht -> Sichtfläche (Stein und Transport bleiben beim Gewicht)
  update ressourcenzeile rz set menge_ausdruck = replace(rz.menge_ausdruck::text, t_gew::text, t_fl::text)::jsonb
   where rz.option_id in (select id from auswahloption where auswahlfeld_id = af_w)
     and coalesce(rz.artikel_id, '00000000-0000-0000-0000-000000000000') not in (a_w, a_s, a_t);
  get diagnostics n = row_count;
  raise notice 'Zeilen auf Sichtfläche umgestellt: %', n;

  -- 3. Optionen umbenennen / Schichten in eigenen Teilschritt
  update teilschritt set name = 'Natursteinmauer Plasselb wechselschichtig' where id = ts_w;
  update auswahlfeld set name = 'Natursteinmauer Plasselb wechselschichtig' where id = af_w;
  select to_jsonb(t) into tmpl from teilschritt t where t.id = ts_w;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_g, 'name', 'Natursteinmauer geschichtet in Blöcken', 'beschreibung', null));
  select to_jsonb(f) into tmpl from auswahlfeld f where f.id = af_w;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_g, 'teilschritt_id', ts_g, 'name', 'Natursteinmauer geschichtet in Blöcken'));
  select array_agg(id) into ids from auswahloption where auswahlfeld_id = af_w and name like 'Schichten %';
  if ids is null or array_length(ids, 1) <> 2 then raise exception 'Erwartet 2 Schichten-Optionen'; end if;
  update auswahloption set auswahlfeld_id = af_g, name = replace(name, 'Schichten Maschine', 'Plasselb Maschine'),
         reihenfolge = case when name like '%Maschine M' then 1 else 2 end where id = any(ids);
  update auswahloption set name = replace(name, 'Wechselschicht ', '') where auswahlfeld_id = af_w;
  -- Reihenfolge der Teilschritte
  update teilschritt set reihenfolge = 1 where id = ts_t;
  update teilschritt set reihenfolge = 2 where id = ts_w;
  update teilschritt set reihenfolge = 3 where id = ts_g;
end $$;
