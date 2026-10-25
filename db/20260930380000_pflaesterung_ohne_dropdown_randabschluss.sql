-- Beläge Pflästerung (Nutzerentscheid 2026-10-25):
--  1) Kein Dropdown Reihen/Bogen mehr: es gilt der Preis der Reihenpflästerung (Splittbeton 85, Splitt 75 EK je m²).
--  2) Randabschluss je Stein (Granit, Guber, Luserna) statt einer Option "Randabschluss Splitbeton":
--     Pflästerer 14 CHF/m (Arbeitszeit steckt im Preis), Stein + Transport, Splittbeton + Lieferwagen, Fugenmörtel + Ausfugen.
--     Annahme: eine Reihe Pflastersteine, 0.12 m breit (= 0.12 m² je Laufmeter).
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz left join artikel a on a.id = rz.artikel_id left join sonderposition_typ st on st.id = rz.sonderposition_typ_id
   where rz.option_id = p_opt and (a.bezeichnung = p_art or st.name = p_art) order by rz.reihenfolge, rz.id limit 1 $$;
create or replace function pg_temp.klon(p_src uuid, p_opt uuid, p_rr int, p_menge jsonb, p_artikel uuid default null, p_versch numeric default null, p_kat text default null) returns void language plpgsql as $$
declare j jsonb;
begin
  if p_src is null then raise exception 'Quellzeile fehlt (Option %, Reihenfolge %)', p_opt, p_rr; end if;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = p_src;
  j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', p_opt, 'teilschritt_id', null, 'reihenfolge', p_rr,
        'menge_ausdruck', p_menge, 'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
        'verschnitt_prozent', p_versch, 'mindestmenge', null, 'mengenoption_ausgenommen', false);
  if p_artikel is not null then j := j || jsonb_build_object('artikel_id', p_artikel, 'bezeichnung_override', null); end if;
  if p_kat is not null then j := j || jsonb_build_object('kategorie', p_kat); end if;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
end $$;

do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d';
  a_rs uuid; a_rp uuid; a_bs uuid; a_bp uuid; a_sick uuid; ids_grp uuid[]; n int;
  af_rand uuid; o_alt uuid; o_gr uuid; o_pf1 uuid; o_pf1_fugen uuid; tmpl jsonb; rr_alt int;
  src_pfl uuid; src_stein uuid; src_tr uuid; src_chauf uuid; src_lw uuid; src_moertel uuid; src_pol uuid; src_gar uuid;
  rec record; oid uuid; breite constant numeric := 0.12; bett constant numeric := 0.05;
begin
  select id into a_rs from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_REIHEN_SPLITBETON';
  select id into a_rp from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_REIHEN_SPLIT';
  select id into a_bs from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_BOGEN_SPLITBETON';
  select id into a_bp from artikel where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_BOGEN_SPLIT';
  select id into a_sick from artikel where bezeichnung = 'Sickerbeton, 200 kg/m3, 4–8 mm Splitt' limit 1;
  select array_agg(id) into ids_grp from auswahlgruppe where name in ('Verlegeart Pflästerung Splittbeton', 'Verlegeart Pflästerung Split');
  if a_rs is null or a_rp is null or a_bs is null or a_bp is null or a_sick is null or array_length(ids_grp, 1) <> 2 then raise exception 'Grundlage Pflästerung nicht gefunden'; end if;

  -- 1) Dropdown entfernen: feste Pflästerer-Zeile (Reihen-Preis)
  update ressourcenzeile rz set auswahlgruppe_id = null, artikel_id = case when ag.name like '%Splittbeton' then a_rs else a_rp end
    from auswahlgruppe ag where ag.id = rz.auswahlgruppe_id and ag.id = any(ids_grp);
  get diagnostics n = row_count;
  if n <> 10 then raise exception 'Erwartet 10 Pflästerer-Zeilen, angepasst %', n; end if;
  delete from auswahlgruppe_option where auswahlgruppe_id = any(ids_grp);
  delete from auswahlgruppe where id = any(ids_grp);
  delete from artikel where id in (a_bs, a_bp);
  update artikel set bezeichnung = 'Pflästerung in Splittbeton (Pflästerer, Fremdleistung)' where id = a_rs;
  update artikel set bezeichnung = 'Pflästerung in Splitt (Pflästerer, Fremdleistung)' where id = a_rp;
  update auswahloption o set hinweistext = 'Pflästerer: Preis gilt für Reihen- und Bogenpflästerung und für grosse Flächen, Kleinflächen beim Pflästerer anfragen. Leistung ca. 12 m² pro Tag, dazu eine Person Mithilfe von uns (halber Tag Vorarbeiter, halber Tag Gartenarbeiter). Bettung: '
      || case when o.hinweistext like '%Splittbeton 8 cm%' then 'Splittbeton 8 cm (Betonwerk)' else 'Split 2/4 mm 4 cm (Kieswerk)' end || ', Lieferung mit Lieferwagen.'
    where o.hinweistext like 'Pflästerer: Verlegeart%';

  -- 2) Randabschluss je Stein
  select f.id, o.id, o.reihenfolge into af_rand, o_alt, rr_alt from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
   where ar.offertentyp_id = ot and ts.name = 'Randbefestigung' and o.name = 'Randabschluss Splitbeton';
  select o.id into o_gr from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
   where ar.offertentyp_id = ot and ts.name = 'Pflastersteine in Splittbeton' and o.name = 'Granit grau P 9/11';
  select o.id into o_pf1 from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
   where ar.offertentyp_id = ot and ts.name = 'Fugen' and o.name = 'PF1 Pflästerung';
  if o_alt is null or o_gr is null or o_pf1 is null then raise exception 'Grundlage Randabschluss nicht gefunden'; end if;
  src_pfl := pg_temp.rz_id(o_alt, 'Randabschluss in Splitbeton (Pflästerer, Fremdleistung)');
  src_stein := pg_temp.rz_id(o_gr, 'Pflasterstein Granit grau fein/mittelkorn (Portugal) P 9/11 rings gespalten');
  src_tr := pg_temp.rz_id(o_gr, 'Transport Natursteinplatten');
  src_chauf := pg_temp.rz_id(o_gr, 'Lieferwagenchauffeur Pool Kieswerk/Betonwerk');
  src_lw := pg_temp.rz_id(o_gr, 'Lieferwagentransport Kieswerk/Betonwerk');
  src_moertel := pg_temp.rz_id(o_pf1, 'SAKRET Pflasterfugenmörtel PF1 sand 25kg');
  src_pol := pg_temp.rz_id(o_pf1, 'Polier / Vorarbeiter');
  src_gar := pg_temp.rz_id(o_pf1, 'Gartenarbeiter');
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_alt;

  for rec in select * from (values
      (0, 'Randabschluss Granit',  'Pflasterstein Granit grau fein/mittelkorn (Portugal) P 9/11 rings gespalten', 0.200, 'Granit grau fein/mittelkorn (Portugal), 9/11, rings gespalten'),
      (1, 'Randabschluss Guber',   'Pflasterstein Guber Quarzsandstein (Schweiz) Typ 12 rings gespalten',        0.250, 'Guber Quarzsandstein (Schweiz), Typ 12, rings gespalten'),
      (2, 'Randabschluss Luserna', 'Pflasterstein Luserna Dorée (Italien) P 8/12 Standard rings gespalten',      0.200, 'Luserna Dorée (Italien), P 8/12 Standard, rings gespalten')
    ) as v(nr, name, art, tm2, beschr) loop
    oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'name', rec.name, 'reihenfolge', rr_alt + rec.nr,
        'beschreibung', 'Randabschluss mit ' || rec.beschr || ' in Splittbeton, durch Pflästerer verlegt, inkl. Verfugen.',
        'hinweistext', 'Menge in Laufmetern. Eine Reihe Pflastersteine (ca. 12 cm breit) in Splittbeton. Pflästerer-Preis pro Meter inkl. Arbeitszeit, gilt für grosse Flächen, Kleinflächen beim Pflästerer anfragen.'));
    perform pg_temp.klon(src_pfl,    oid, 1, pg_temp.f_lit(1));
    perform pg_temp.klon(src_stein,  oid, 2, pg_temp.f_lit(round(breite * rec.tm2, 4)), (select id from artikel where bezeichnung = rec.art), 10);
    perform pg_temp.klon(src_tr,     oid, 3, pg_temp.f_lit(round(breite * rec.tm2, 4)), null, 10);
    perform pg_temp.klon(src_stein,  oid, 4, pg_temp.f_lit(bett), a_sick, 5);
    perform pg_temp.klon(src_chauf,  oid, 5, pg_temp.f_lit(round(bett * 0.75 * 2, 3)));
    perform pg_temp.klon(src_lw,     oid, 6, pg_temp.f_lit(round(bett * 0.75 * 2, 3)));
    perform pg_temp.klon(src_moertel, oid, 7, pg_temp.f_lit(round(breite * 0.8, 3)));
    perform pg_temp.klon(src_pol,    oid, 8, pg_temp.f_lit(round(breite * 0.17, 4)));
    perform pg_temp.klon(src_gar,    oid, 9, pg_temp.f_lit(round(breite * 0.17, 4)));
  end loop;

  -- alte Option entfernen (inkl. Auswahl in bestehenden Offerten)
  delete from offerte_auswahl where option_id = o_alt;
  update offerte_tabelle_zeile set option_ids = array_remove(option_ids, o_alt) where option_ids @> array[o_alt];
  delete from ressourcenzeile where option_id = o_alt;
  delete from option_freitext_vorlage where option_id = o_alt;
  delete from auswahloption where id = o_alt;
  select count(*) into n from auswahloption where auswahlfeld_id = af_rand and name like 'Randabschluss %';
  if n <> 3 then raise exception 'Erwartet 3 Randabschluss-Optionen, gefunden %', n; end if;
end $$;

update artikel set bezeichnung = 'Randabschluss in Splittbeton (Pflästerer, Fremdleistung)' where artikelnummer_knecht = 'KNECHT_PFLAESTERUNG_RANDABSCHLUSS';
