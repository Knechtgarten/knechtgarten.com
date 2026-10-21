-- Natursteinmauer: Plasselb Schichten (300-500 L) neben Wechselschicht, im selben Feld
-- (so ist immer nur eine Art wählbar). Personal 2.2 Std/t statt 4.5, Maschinen 1.32 Std/t statt 2.7
-- (Werte aus dem Berechnungstool), Stein = Artikel "Plasselb Natursteinblöcke 300-500 L (Schichten)".
do $$
declare
  ot uuid; as_nat uuid; af uuid; ts uuid; a_w uuid; a_s uuid; rec record; oid uuid; rr int; tmpl jsonb; n int;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_nat from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer';
  select t.id, f.id into ts, af from teilschritt t join auswahlfeld f on f.teilschritt_id = t.id where t.arbeitsschritt_id = as_nat and t.name = 'Natursteinmauer Plasselb Wechselschicht';
  select id into a_w from artikel where bezeichnung = 'Plasselb Natursteinblöcke 50-100 L (Wechselschicht)';
  select id into a_s from artikel where bezeichnung = 'Plasselb Natursteinblöcke 300-500 L (Schichten)';
  if af is null or a_w is null or a_s is null then raise exception 'Grundlage nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af and name like 'Schichten%') then raise exception 'Schichten gibt es schon'; end if;

  select max(reihenfolge) into rr from auswahloption where auswahlfeld_id = af;
  -- neue Optionen aus den bestehenden ableiten (vor dem Umbenennen)
  for rec in select o.* from auswahloption o where o.auswahlfeld_id = af order by o.reihenfolge loop
    rr := rr + 1; oid := gen_random_uuid();
    tmpl := to_jsonb(rec);
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'name', 'Schichten ' || rec.name, 'reihenfolge', rr,
      'beschreibung', replace(replace(coalesce(rec.beschreibung, ''), 'im Wechselschichtverband', 'in Schichten'), 'Plasselb-Blöcken', 'Plasselb-Blöcken (300-500 L)')));
    insert into ressourcenzeile select * from jsonb_populate_recordset(null::ressourcenzeile,
      (select jsonb_agg(to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', oid,
          'artikel_id', case when rz.artikel_id = a_w then a_s else rz.artikel_id end,
          'menge_ausdruck', case when rz.kategorie = 'personal' then replace(rz.menge_ausdruck::text, '"lit": 4.5', '"lit": 2.2')::jsonb
                                 when rz.kategorie = 'maschine' then replace(rz.menge_ausdruck::text, '"lit": 2.7', '"lit": 1.32')::jsonb
                                 else rz.menge_ausdruck end)) from ressourcenzeile rz where rz.option_id = rec.id));
    select count(*) into n from ressourcenzeile where option_id = oid; if n = 0 then raise exception 'Keine Zeilen fuer %', rec.name; end if;
  end loop;
  update auswahloption set name = 'Wechselschicht ' || name where auswahlfeld_id = af and name not like 'Schichten %';
  update teilschritt set name = 'Natursteinmauer Plasselb' where id = ts;
  update auswahlfeld set name = 'Natursteinmauer Plasselb' where id = af;
  raise notice 'Schichten angelegt.';
end $$;
