-- ============================================================================
-- Beläge: Pflästerung verlegen (Pflästerer als Fremdleistung) + Randabschluss Splitbeton, Fugen nachkontrolliert
--  * Artikel (Lieferant Knechtgarten): Pflästerung Reihen/Bogen in Splitbeton und Split (EK 85/80/75/70, VK = EK x 1.2),
--    Randabschluss Splitbeton (EK 14/m), Splitt 2/4 mm (Kieswerk Heimberg)
--  * Teilschritt "Pflästerung verlegen" (eigener Arbeitsschritt "Pflästerung" vor den Fugen), Tabellenverweis auf die
--    Flächen (Gruppe "verlegung"): Fremdleistung je m², eigene Mithilfe 0.375 Std/m² je Person (12 m²/Tag, Polier und
--    Gartenarbeiter je einen halben Tag), Bettung Splitbeton 8 cm (Sickerbeton 250, Beton-Transport) bzw. Split 2/4 4 cm
--  * Randbefestigung: Option "Randabschluss Splitbeton" (Pflästerer 14 CHF/m)
--  * Fugen: PF1/PFU Pflästerung 0.17 Std je Person (80 m²/Tag mit 3 Personen), PFU mit PU-Mörtel
-- ============================================================================
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;

create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz left join artikel a on a.id = rz.artikel_id left join sonderposition_typ st on st.id = rz.sonderposition_typ_id
   where rz.option_id = p_opt and (a.bezeichnung = p_art or st.name = p_art) order by rz.reihenfolge, rz.id limit 1 $$;

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

create or replace function pg_temp.neuer_artikel(p_lief uuid, p_kat text, p_nr text, p_bez text, p_einheit text, p_ep numeric, p_vp numeric) returns uuid language plpgsql as $$
declare nid uuid := gen_random_uuid();
begin
  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values (nid, p_lief, p_kat, 'KNECHT_' || p_nr, p_nr, p_bez, p_einheit, p_ep, p_vp, 'CHF', 1, 8.1, false, false, false, true, false);
  return nid;
end $$;

do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d'; pool_ot uuid; kg uuid := 'db9c6bd1-ee9d-40a4-9d1f-723faba51728'; hei uuid;
  ef uuid; sp_fl uuid; as_fugen uuid; ts_fugen uuid; af_fugen uuid; o_pf1 uuid; o_pfu uuid; as_neu uuid := gen_random_uuid(); ts_neu uuid := gen_random_uuid(); af_neu uuid := gen_random_uuid();
  a_rs uuid; a_bs uuid; a_rp uuid; a_bp uuid; a_rand uuid; a_split24 uuid; a_sick uuid; a_pu uuid; a_pf1 uuid;
  src_pol uuid; src_gar uuid; src_mat uuid; src_bt uuid; src_lw uuid; o_mergel uuid; pool_sb uuid; tmpl jsonb; rec record; oid uuid; rr int; verw jsonb; n int;
  o_randbeton uuid; o_rand uuid := gen_random_uuid(); af_rand uuid; ts_rand uuid;
begin
  select id into pool_ot from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  select id into hei from lieferant where name = 'Kieswerk Heimberg AG';
  select id into ef from eingabefeld where offertentyp_id = ot and name = 'Flächen' and ist_tabelle;
  select id into sp_fl from eingabefeld_tabelle_spalte where eingabefeld_id = ef and name = 'Fläche';
  select a.id, ts.id, af.id into as_fugen, ts_fugen, af_fugen from arbeitsschritt a join teilschritt ts on ts.arbeitsschritt_id = a.id join auswahlfeld af on af.teilschritt_id = ts.id where a.offertentyp_id = ot and ts.name = 'Fugen';
  select o.id into o_pf1 from auswahloption o where o.auswahlfeld_id = af_fugen and o.name = 'PF1 Pflästerung';
  select o.id into o_pfu from auswahloption o where o.auswahlfeld_id = af_fugen and o.name = 'PFU Pflästerung';
  select o.id into o_mergel from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and o.name = 'Mergel';
  select o.id into pool_sb from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = pool_ot and ts.name ilike '%hinterf%' and o.name = 'Sickerbeton';
  select o.id, f.id, ts.id into o_randbeton, af_rand, ts_rand from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and ts.name = 'Randbefestigung' and o.name = 'Randbeton';
  select id into a_sick from artikel where bezeichnung = 'Sickerbeton, 200 kg/m3, 4–8 mm Splitt' limit 1;
  select id into a_pu from artikel where bezeichnung = 'SAKRET Pflasterfugenmörtel PU sand 25kg' limit 1;
  select id into a_pf1 from artikel where bezeichnung = 'SAKRET Pflasterfugenmörtel PF1 sand 25kg' limit 1;
  if ef is null or sp_fl is null or as_fugen is null or o_pf1 is null or o_pfu is null or o_mergel is null or pool_sb is null or o_randbeton is null or a_sick is null or a_pu is null or a_pf1 is null or hei is null then
    raise exception 'Grundlage nicht gefunden - nichts geaendert.';
  end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Pflästerung') then raise exception 'Pflästerung gibt es schon'; end if;

  -- Artikel (VK = EK x 1.2)
  a_rs    := pg_temp.neuer_artikel(kg, 'logistik', 'PFLAESTERUNG_REIHEN_SPLITBETON', 'Pflästerung Reihen in Splitbeton (Pflästerer, Fremdleistung)', 'm²', 85, 102);
  a_bs    := pg_temp.neuer_artikel(kg, 'logistik', 'PFLAESTERUNG_BOGEN_SPLITBETON',  'Pflästerung Bogen in Splitbeton (Pflästerer, Fremdleistung)',  'm²', 80, 96);
  a_rp    := pg_temp.neuer_artikel(kg, 'logistik', 'PFLAESTERUNG_REIHEN_SPLIT',      'Pflästerung Reihen in Split (Pflästerer, Fremdleistung)',      'm²', 75, 90);
  a_bp    := pg_temp.neuer_artikel(kg, 'logistik', 'PFLAESTERUNG_BOGEN_SPLIT',       'Pflästerung Bogen in Split (Pflästerer, Fremdleistung)',       'm²', 70, 84);
  a_rand  := pg_temp.neuer_artikel(kg, 'logistik', 'PFLAESTERUNG_RANDABSCHLUSS',     'Randabschluss in Splitbeton (Pflästerer, Fremdleistung)',      'm',  14, 16.80);
  a_split24 := pg_temp.neuer_artikel(hei, 'material', 'SPLITT_2_4', 'Splitt 2/4 mm', 'm³', 66.5, 83);

  -- Struktur: eigener Arbeitsschritt vor den Fugen
  update arbeitsschritt set reihenfolge = reihenfolge + 1 where offertentyp_id = ot and reihenfolge >= (select reihenfolge from arbeitsschritt where id = as_fugen);
  select to_jsonb(a) into tmpl from arbeitsschritt a where a.id = as_fugen;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, tmpl || jsonb_build_object('id', as_neu, 'name', 'Pflästerung', 'reihenfolge', (select reihenfolge - 1 from arbeitsschritt where id = as_fugen)));
  select to_jsonb(t) into tmpl from teilschritt t where t.id = ts_fugen;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_neu, 'arbeitsschritt_id', as_neu, 'name', 'Pflästerung verlegen', 'reihenfolge', 1, 'beschreibung', null));
  select to_jsonb(f) into tmpl from auswahlfeld f where f.id = af_fugen;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', 'Pflästerung verlegen'));

  src_pol := pg_temp.rz_id(o_pf1, 'Polier / Vorarbeiter');
  src_gar := pg_temp.rz_id(o_pf1, 'Gartenarbeiter');
  src_mat := pg_temp.rz_id(o_pf1, 'SAKRET Pflasterfugenmörtel PF1 sand 25kg');
  src_bt  := pg_temp.rz_id(pool_sb, 'Beton-Transport');
  src_lw  := pg_temp.rz_id(o_mergel, 'Lieferwagentransport Kieswerk/Betonwerk');
  verw := jsonb_build_array(jsonb_build_object('eingabefeld_id', ef, 'spalte_id', sp_fl, 'gruppe', 'verlegung'));
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_pf1;

  rr := 0;
  for rec in select * from (values
      ('Reihenpflästerung Splitbeton', a_rs, true,  'Pflästerung in Reihen im Splitbett durch Pflästerer.'),
      ('Bogenpflästerung Splitbeton',  a_bs, true,  'Bogenpflästerung im Splitbeton durch Pflästerer.'),
      ('Reihenpflästerung Split',      a_rp, false, 'Pflästerung in Reihen im Split 2/4 mm durch Pflästerer.'),
      ('Bogenpflästerung Split',       a_bp, false, 'Bogenpflästerung im Split 2/4 mm durch Pflästerer.')
    ) as v(name, art, splitbeton, beschr) loop
    rr := rr + 1; oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', af_neu, 'name', rec.name, 'reihenfolge', rr,
        'beschreibung', rec.beschr, 'hinweistext', 'Preis gilt für grosse Flächen, Kleinflächen beim Pflästerer anfragen.', 'mengenoption', false, 'mehrfachauswahl', true, 'tabellenverweis', verw));
    perform pg_temp.klon(src_mat, oid, 1, pg_temp.f_lit(1), rec.art);                 -- Fremdleistung Pflästerer je m²
    perform pg_temp.klon(src_pol, oid, 2, pg_temp.f_lit(0.375));                       -- Mithilfe: 12 m²/Tag, halber Tag je Person
    perform pg_temp.klon(src_gar, oid, 3, pg_temp.f_lit(0.375));
    if rec.splitbeton then
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_lit(0.08), a_sick, 5);           -- Bettung 8 cm
      perform pg_temp.klon(src_bt,  oid, 5, pg_temp.f_lit(0.08));
    else
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_lit(0.04), a_split24, 5);        -- Bettung 4 cm
      perform pg_temp.klon(src_lw,  oid, 5, pg_temp.f_lit(0.07));
    end if;
  end loop;

  -- Randabschluss Splitbeton (aus "Randbeton" abgeleitet)
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_randbeton;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', o_rand, 'name', 'Randabschluss Splitbeton', 'reihenfolge', (select max(reihenfolge) + 1 from auswahloption where auswahlfeld_id = af_rand),
      'beschreibung', 'Randabschluss in Splitbeton durch Pflästerer.', 'hinweistext', 'Preis gilt für grosse Flächen, Kleinflächen beim Pflästerer anfragen.'));
  insert into ressourcenzeile select * from jsonb_populate_recordset(null::ressourcenzeile,
    (select jsonb_agg(to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', o_rand)) from ressourcenzeile rz where rz.option_id = o_randbeton));
  update ressourcenzeile set menge_ausdruck = pg_temp.f_lit(0.1) where option_id = o_rand and kategorie = 'personal';
  perform pg_temp.klon(pg_temp.rz_id(o_randbeton, 'Sickerbeton, 200 kg/m3, 4–8 mm Splitt'), o_rand, 10, pg_temp.f_lit(1), a_rand);

  -- Fugen nachkontrolliert: 80 m²/Tag mit 3 Personen = 0.34 Std/m² -> 0.17 je Person bei zwei Personen
  update ressourcenzeile set menge_ausdruck = pg_temp.f_lit(0.17) where option_id in (o_pf1, o_pfu) and kategorie = 'personal';
  update ressourcenzeile set artikel_id = a_pu where option_id = o_pfu and artikel_id = a_pf1;
  get diagnostics n = row_count;
  -- Pflästerer-Leistungen erscheinen in der Offerte unter Maschinenaufwand (Fremdleistung)
  update ressourcenzeile set kategorie = 'maschine' where artikel_id in (a_rs, a_bs, a_rp, a_bp, a_rand);
  raise notice 'Pflästerung angelegt, PFU-Artikel ersetzt: %', n;
end $$;
