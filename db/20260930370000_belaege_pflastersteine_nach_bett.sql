-- Beläge: Pflästerung neu gegliedert nach Bettung (Nutzerentscheid):
--   Teilschritt "Pflastersteine in Splittbeton" und "Pflastersteine in Splitt", je 5 Steinarten als Buttons.
--   Pro Button: Stein + Fontarocca-Transport (Verschnitt 10 %), Pflästerer-Fremdleistung (Dropdown Reihen/Bogen = Auswahlgruppe,
--   Preis je m²), Mithilfe 0.375 Std/m² je Person, Bettung (Splittbeton 8 cm / Split 2/4 4 cm), Lieferwagen ab Betonwerk bzw. Kieswerk.
--   Ersetzt die bisherigen Arbeitsschritte "Pflastersteine" und "Pflästerung" (nur Testdaten betroffen).
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz left join artikel a on a.id = rz.artikel_id left join sonderposition_typ st on st.id = rz.sonderposition_typ_id
   where rz.option_id = p_opt and (a.bezeichnung = p_art or st.name = p_art) order by rz.reihenfolge, rz.id limit 1 $$;
create or replace function pg_temp.klon(p_src uuid, p_opt uuid, p_rr int, p_menge jsonb, p_artikel uuid default null, p_versch numeric default null, p_kat text default null, p_gruppe uuid default null) returns void language plpgsql as $$
declare j jsonb;
begin
  if p_src is null then raise exception 'Quellzeile fehlt (Option %, Reihenfolge %)', p_opt, p_rr; end if;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = p_src;
  j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', p_opt, 'teilschritt_id', null, 'reihenfolge', p_rr,
        'menge_ausdruck', p_menge, 'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
        'verschnitt_prozent', p_versch, 'mindestmenge', null, 'mengenoption_ausgenommen', false);
  if p_artikel is not null then j := j || jsonb_build_object('artikel_id', p_artikel, 'bezeichnung_override', null); end if;
  if p_kat is not null then j := j || jsonb_build_object('kategorie', p_kat); end if;
  if p_gruppe is not null then j := j || jsonb_build_object('artikel_id', null, 'bezeichnung_override', null, 'auswahlgruppe_id', p_gruppe); end if;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
end $$;

do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d'; as_alt uuid[]; ids_opt uuid[]; ts_alt uuid[]; af_alt uuid[];
  as_fugen uuid; as_neu uuid := gen_random_uuid(); ts_k uuid; af_k uuid; o_pia uuid; o_pf1 uuid; af_fugen uuid; o_kw uuid;
  a_rs uuid; a_bs uuid; a_rp uuid; a_bp uuid; a_sick uuid; a_split uuid; g1 uuid := gen_random_uuid(); g2 uuid := gen_random_uuid();
  src_pol uuid; src_gar uuid; src_mat uuid; src_tr uuid; src_chauf uuid; src_lw uuid; tmpl jsonb; rec record; bett record; oid uuid; rr int; ts_n uuid; af_n uuid; n int;
begin
  select array_agg(id) into as_alt from arbeitsschritt where offertentyp_id = ot and name in ('Pflastersteine', 'Pflästerung');
  if as_alt is null or array_length(as_alt, 1) <> 2 then raise exception 'Erwartet 2 alte Arbeitsschritte, gefunden %', coalesce(array_length(as_alt, 1), 0); end if;
  select a.id, af.id into as_fugen, af_fugen from arbeitsschritt a join teilschritt ts on ts.arbeitsschritt_id = a.id join auswahlfeld af on af.teilschritt_id = ts.id where a.offertentyp_id = ot and ts.name = 'Fugen';
  select o.id into o_pf1 from auswahloption o where o.auswahlfeld_id = af_fugen and o.name = 'PF1 Pflästerung';
  select ts.id, af.id into ts_k, af_k from arbeitsschritt a join teilschritt ts on ts.arbeitsschritt_id = a.id join auswahlfeld af on af.teilschritt_id = ts.id where a.offertentyp_id = ot and ts.name = 'Natursteinbelag Bahnen geflammt';
  select o.id into o_pia from auswahloption o where o.auswahlfeld_id = af_k and o.name = 'Piazentina';
  select o.id into o_kw from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
   where a.offertentyp_id = (select id from offertentyp where name = 'Mauern' and papierkorb_am is null) and o.name = 'Kies Lieferwagen';
  select id into a_rs from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_REIHEN_SPLITBETON';
  select id into a_bs from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_BOGEN_SPLITBETON';
  select id into a_rp from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_REIHEN_SPLIT';
  select id into a_bp from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_BOGEN_SPLIT';
  select id into a_sick from artikel where bezeichnung = 'Sickerbeton, 200 kg/m3, 4–8 mm Splitt' limit 1;
  select id into a_split from artikel where artikelnummer_knecht = 'KNECHT_SPLITT_2_4';
  if o_pf1 is null or o_pia is null or o_kw is null or a_rs is null or a_bs is null or a_rp is null or a_bp is null or a_sick is null or a_split is null then raise exception 'Grundlage nicht gefunden'; end if;

  src_pol := pg_temp.rz_id(o_pf1, 'Polier / Vorarbeiter');
  src_gar := pg_temp.rz_id(o_pf1, 'Gartenarbeiter');
  src_mat := pg_temp.rz_id(o_pf1, 'SAKRET Pflasterfugenmörtel PF1 sand 25kg');
  src_tr  := pg_temp.rz_id(o_pia, 'Transport Natursteinplatten');
  src_chauf := pg_temp.rz_id(o_kw, 'Lieferwagenchauffeur Pool Kieswerk/Betonwerk');
  src_lw  := pg_temp.rz_id(o_kw, 'Lieferwagentransport Kieswerk/Betonwerk');

  -- Alte Pflästerungs-Struktur entfernen
  select array_agg(o.id) into ids_opt from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id where ts.arbeitsschritt_id = any(as_alt);
  select array_agg(ts.id) into ts_alt from teilschritt ts where ts.arbeitsschritt_id = any(as_alt);
  select array_agg(f.id) into af_alt from auswahlfeld f where f.teilschritt_id = any(ts_alt);
  -- Auswahl der alten Optionen in bestehenden Offerten loeschen (Offerte bleibt, Zuordnung muss neu gewaehlt werden)
  delete from offerte_auswahl where option_id = any(ids_opt);
  update offerte_tabelle_zeile set option_ids = array(select x from unnest(option_ids) x where x <> all(ids_opt)) where option_ids && ids_opt;
  delete from ressourcenzeile where option_id = any(ids_opt);
  delete from option_freitext_vorlage where option_id = any(ids_opt);
  delete from auswahloption where id = any(ids_opt);
  delete from auswahlfeld where id = any(af_alt);
  delete from teilschritt where id = any(ts_alt);
  delete from arbeitsschritt where id = any(as_alt);

  -- Auswahlgruppen Verlegeart (Pflästerer-Preis je m²)
  insert into auswahlgruppe (id, name, titel, kategorie) values (g1, 'Verlegeart Pflästerung Splittbeton', 'Verlegeart', 'maschine'), (g2, 'Verlegeart Pflästerung Split', 'Verlegeart', 'maschine');
  insert into auswahlgruppe_option (auswahlgruppe_id, label, artikel_id, reihenfolge) values
    (g1, 'Reihenpflästerung', a_rs, 1), (g1, 'Bogenpflästerung', a_bs, 2), (g2, 'Reihenpflästerung', a_rp, 1), (g2, 'Bogenpflästerung', a_bp, 2);

  -- neuer Arbeitsschritt vor den Fugen
  update arbeitsschritt set reihenfolge = reihenfolge + 1 where offertentyp_id = ot and reihenfolge >= (select reihenfolge from arbeitsschritt where id = as_fugen);
  select to_jsonb(a) into tmpl from arbeitsschritt a where a.id = as_fugen;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, tmpl || jsonb_build_object('id', as_neu, 'name', 'Pflästerung', 'reihenfolge', (select reihenfolge - 1 from arbeitsschritt where id = as_fugen)));

  for bett in select * from (values
      (1, 'Pflastersteine in Splittbeton', g1, a_sick, 0.08, 'Splittbeton 8 cm (Betonwerk)'),
      (2, 'Pflastersteine in Splitt',      g2, a_split, 0.04, 'Split 2/4 mm 4 cm (Kieswerk)')
    ) as v(nr, ts_name, grp, bett_art, bett_m3, bett_txt) loop
    ts_n := gen_random_uuid(); af_n := gen_random_uuid();
    select to_jsonb(t) into tmpl from teilschritt t where t.id = ts_k;
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_n, 'arbeitsschritt_id', as_neu, 'name', bett.ts_name, 'reihenfolge', bett.nr, 'beschreibung', null));
    select to_jsonb(f) into tmpl from auswahlfeld f where f.id = af_k;
    insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_n, 'teilschritt_id', ts_n, 'name', bett.ts_name));
    select to_jsonb(o) into tmpl from auswahloption o where o.id = o_pia;
    rr := 0;
    for rec in select * from (values
        ('Granit grau P 9/11',   'Pflasterstein Granit grau fein/mittelkorn (Portugal) P 9/11 rings gespalten', 0.200, 'Granit grau fein/mittelkorn (Portugal), 9/11, rings gespalten'),
        ('Guber 8/11',           'Pflasterstein Guber Quarzsandstein (Schweiz) 8/11 rings gespalten',          0.188, 'Guber Quarzsandstein (Schweiz), 8/11, rings gespalten'),
        ('Guber Typ 12',         'Pflasterstein Guber Quarzsandstein (Schweiz) Typ 12 rings gespalten',        0.250, 'Guber Quarzsandstein (Schweiz), Typ 12, rings gespalten'),
        ('Guber Wildpflaster',   'Wildpflaster Guber Quarzsandstein (Schweiz) 2-6/8-11 rings gespalten',       0.185, 'Wildpflaster aus Guber Quarzsandstein (Schweiz), 2-6/8-11, rings gespalten'),
        ('Luserna Dorée P 8/12', 'Pflasterstein Luserna Dorée (Italien) P 8/12 Standard rings gespalten',      0.200, 'Luserna Dorée (Italien), P 8/12 Standard, rings gespalten')
      ) as s(name, art, tm2, beschr) loop
      rr := rr + 1; oid := gen_random_uuid();
      insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', af_n, 'name', rec.name, 'reihenfolge', rr,
          'beschreibung', 'Pflästerung mit ' || rec.beschr || ' in ' || bett.bett_txt || ', durch Pflästerer verlegt.',
          'hinweistext', 'Pflästerer: Verlegeart Reihen oder Bogen im Dropdown wählen. Preis gilt für grosse Flächen, Kleinflächen beim Pflästerer anfragen. Leistung ca. 12 m² pro Tag, dazu eine Person Mithilfe von uns (halber Tag Vorarbeiter, halber Tag Gartenarbeiter). Bettung: ' || bett.bett_txt || ', Lieferung mit Lieferwagen.'));
      perform pg_temp.klon(src_mat, oid, 1, pg_temp.f_lit(1), null, null, 'maschine', bett.grp);
      perform pg_temp.klon(src_pol, oid, 2, pg_temp.f_lit(0.375));
      perform pg_temp.klon(src_gar, oid, 3, pg_temp.f_lit(0.375));
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_lit(rec.tm2), (select id from artikel where bezeichnung = rec.art), 10, 'material');
      perform pg_temp.klon(src_tr,  oid, 5, pg_temp.f_lit(rec.tm2), null, 10);
      perform pg_temp.klon(src_mat, oid, 6, pg_temp.f_lit(bett.bett_m3), bett.bett_art, 5, 'material');
      perform pg_temp.klon(src_chauf, oid, 7, pg_temp.f_lit(round(bett.bett_m3 * 0.75 * 2, 3)));
      perform pg_temp.klon(src_lw,    oid, 8, pg_temp.f_lit(round(bett.bett_m3 * 0.75 * 2, 3)));
    end loop;
  end loop;
  select count(*) into n from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id where ts.arbeitsschritt_id = as_neu;
  if n <> 10 then raise exception 'Erwartet 10 Optionen, angelegt %', n; end if;
end $$;
