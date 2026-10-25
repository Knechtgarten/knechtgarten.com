-- Beläge: Teilschritt "Pflastersteine" (Fontarocca): Menge = Bedarf kg/m² / 1000 t je m², Verschnitt 10 %,
-- Transport Fontarocca (Transport Natursteinplatten) einmal je Tonne. Zuordnung zu den Flächen wie bei den Natursteinbelägen.
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz left join artikel a on a.id = rz.artikel_id where rz.option_id = p_opt and a.bezeichnung = p_art order by rz.reihenfolge, rz.id limit 1 $$;
create or replace function pg_temp.klon(p_src uuid, p_opt uuid, p_rr int, p_menge jsonb, p_artikel uuid default null, p_versch numeric default null) returns void language plpgsql as $$
declare j jsonb;
begin
  if p_src is null then raise exception 'Quellzeile fehlt (Option %, Reihenfolge %)', p_opt, p_rr; end if;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = p_src;
  j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', p_opt, 'teilschritt_id', null, 'reihenfolge', p_rr,
        'menge_ausdruck', p_menge, 'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
        'verschnitt_prozent', p_versch, 'mindestmenge', null, 'mengenoption_ausgenommen', false);
  if p_artikel is not null then j := j || jsonb_build_object('artikel_id', p_artikel, 'bezeichnung_override', null); end if;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
end $$;

do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d'; as_k uuid; ts_k uuid; af_k uuid; o_tmpl uuid; as_neu uuid := gen_random_uuid(); ts_neu uuid := gen_random_uuid(); af_neu uuid := gen_random_uuid();
  as_pfl uuid; tmpl jsonb; rec record; oid uuid; rr int := 0; src_stein uuid; src_tr uuid; a_tr uuid;
begin
  select a.id, ts.id, af.id into as_k, ts_k, af_k from arbeitsschritt a join teilschritt ts on ts.arbeitsschritt_id = a.id join auswahlfeld af on af.teilschritt_id = ts.id where a.offertentyp_id = ot and ts.name = 'Natursteinbelag Bahnen geflammt';
  select o.id into o_tmpl from auswahloption o where o.auswahlfeld_id = af_k and o.name = 'Piazentina';
  select id into as_pfl from arbeitsschritt where offertentyp_id = ot and name = 'Pflästerung';
  if as_k is null or o_tmpl is null or as_pfl is null then raise exception 'Grundlage nicht gefunden'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Pflastersteine') then raise exception 'Pflastersteine gibt es schon'; end if;
  src_stein := pg_temp.rz_id(o_tmpl, 'Platten Piazentina geflammt FL 40/3cm');
  src_tr := pg_temp.rz_id(o_tmpl, 'Transport Natursteinplatten');

  -- eigener Arbeitsschritt direkt vor "Pflästerung"
  update arbeitsschritt set reihenfolge = reihenfolge + 1 where offertentyp_id = ot and reihenfolge >= (select reihenfolge from arbeitsschritt where id = as_pfl);
  select to_jsonb(a) into tmpl from arbeitsschritt a where a.id = as_pfl;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, tmpl || jsonb_build_object('id', as_neu, 'name', 'Pflastersteine', 'reihenfolge', (select reihenfolge - 1 from arbeitsschritt where id = as_pfl)));
  select to_jsonb(t) into tmpl from teilschritt t where t.id = ts_k;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_neu, 'arbeitsschritt_id', as_neu, 'name', 'Pflastersteine', 'reihenfolge', 1));
  select to_jsonb(f) into tmpl from auswahlfeld f where f.id = af_k;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', 'Pflastersteine'));
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_tmpl;

  for rec in select * from (values
      ('Granit grau P 9/11',        'Pflasterstein Granit grau fein/mittelkorn (Portugal) P 9/11 rings gespalten', 0.200, 'Pflästerung mit Granit grau fein/mittelkorn (Portugal), 9/11, rings gespalten.'),
      ('Guber 8/11',                'Pflasterstein Guber Quarzsandstein (Schweiz) 8/11 rings gespalten',          0.188, 'Pflästerung mit Guber Quarzsandstein (Schweiz), 8/11, rings gespalten.'),
      ('Guber Typ 12',              'Pflasterstein Guber Quarzsandstein (Schweiz) Typ 12 rings gespalten',        0.250, 'Pflästerung mit Guber Quarzsandstein (Schweiz), Typ 12, rings gespalten.'),
      ('Guber Wildpflaster',        'Wildpflaster Guber Quarzsandstein (Schweiz) 2-6/8-11 rings gespalten',       0.185, 'Wildpflaster aus Guber Quarzsandstein (Schweiz), 2-6/8-11, rings gespalten.'),
      ('Luserna Dorée P 8/12',      'Pflasterstein Luserna Dorée (Italien) P 8/12 Standard rings gespalten',      0.200, 'Pflästerung mit Luserna Dorée (Italien), P 8/12 Standard, rings gespalten.')
    ) as v(name, art, tm2, beschr) loop
    rr := rr + 1; oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', af_neu, 'name', rec.name, 'reihenfolge', rr, 'beschreibung', rec.beschr));
    perform pg_temp.klon(src_stein, oid, 1, pg_temp.f_lit(rec.tm2), (select id from artikel where bezeichnung = rec.art), 10);
    perform pg_temp.klon(src_tr,    oid, 2, pg_temp.f_lit(rec.tm2), null, 10);
  end loop;
end $$;
