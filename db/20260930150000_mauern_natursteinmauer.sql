-- ============================================================================
-- Mauern: Natursteinmauer (Plasselb Wechselschicht), Hinterfüllung, Fundation neu
--  1. Artikel: 3 Plasselb-Artikel (Lieferant Knechtgarten)
--  2. Tabelle "Fundation" -> "Natursteinmauer" (Länge, Höhe, Fundamentbreite, Fundamenttiefe,
--     Hinterfüllbreite; Rechenspalten ausgeblendet) + neue Formeln
--  3. Fundation: Kies LKW / Kies Lieferwagen / Beton LKW gepumpt / Beton Lieferwagen,
--     mit Tabellenverweis (Gruppe "fundation") auf Natursteinmauer + Blendmauer;
--     Fundament-Beton (SVB, Personal, Transport) wandert aus der Betonmauer hierher
--  4. Betonmauer (Coffra): nur noch Wand
--  5. Verputzen: Tabellenverweis (Gruppe "verputzen") auf Blendmauer
--  6. Arbeitsschritt "Natursteinmauer" (von Hand / Maschine S, M, L)
--  7. Arbeitsschritt "Hinterfüllung": Teilschritt Kies (4 Buttons), Teilschritt Sickerbeton (3 Buttons)
-- ============================================================================
create or replace function pg_temp.f_ref(art text, id uuid) returns jsonb language sql as $$ select jsonb_build_object('id', id, 'ref', art) $$;
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.f_mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','*','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_div(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','/','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_add(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','+','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_ceil(a jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','ceil','args', jsonb_build_array(a)) $$;

-- Ressourcenzeile einer Option finden (Artikelname, Sonderposition-Name, oder '#staffel' = Staffel-Zeile, z.B. Betonpumpe)
create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz
    left join artikel a on a.id = rz.artikel_id
    left join sonderposition_typ st on st.id = rz.sonderposition_typ_id
   where rz.option_id = p_opt
     and ( a.bezeichnung = p_art or st.name = p_art or (p_art = '#staffel' and rz.staffelgruppe_id is not null) )
   order by rz.reihenfolge, rz.id limit 1 $$;

-- Ressourcenzeile kopieren: neue Option, neue Menge-Formel, Verschnitt, Mengenoption-Ausnahme
create or replace function pg_temp.klon(p_src uuid, p_opt uuid, p_rr int, p_menge jsonb, p_versch numeric default null, p_ausg boolean default false, p_artikel uuid default null) returns void language plpgsql as $$
declare j jsonb;
begin
  if p_src is null then raise exception 'Quellzeile fehlt (Option %, Reihenfolge %)', p_opt, p_rr; end if;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = p_src;
  j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', p_opt, 'teilschritt_id', null, 'reihenfolge', p_rr,
        'menge_ausdruck', p_menge, 'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
        'verschnitt_prozent', p_versch, 'mindestmenge', null, 'mengenoption_ausgenommen', p_ausg);
  if p_artikel is not null then j := j || jsonb_build_object('artikel_id', p_artikel, 'bezeichnung_override', null); end if;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
end $$;

do $$
declare
  ot uuid; pool_ot uuid; kg uuid := 'db9c6bd1-ee9d-40a4-9d1f-723faba51728';
  a_w uuid := gen_random_uuid(); a_s uuid := gen_random_uuid(); a_t uuid := gen_random_uuid();
  ef_nat uuid; ef_bl uuid;
  sp_l uuid; sp_b uuid; sp_t uuid; sp_v uuid;
  sp_h uuid := gen_random_uuid(); sp_hb uuid := gen_random_uuid(); sp_lz uuid := gen_random_uuid(); sp_fl uuid := gen_random_uuid();
  sp_gw uuid := gen_random_uuid(); sp_hv uuid := gen_random_uuid(); sp_bl_fb uuid; sp_bl_fl uuid;
  t_afk uuid; t_val uuid; t_wand uuid;
  t_zus uuid := gen_random_uuid(); t_tpm uuid := gen_random_uuid(); t_gew uuid := gen_random_uuid(); t_hl uuid := gen_random_uuid(); t_hf uuid := gen_random_uuid();
  tmpl jsonb; j jsonb;
  as_fund uuid; as_blend uuid; as_aush uuid; as_nat uuid := gen_random_uuid(); as_hin uuid := gen_random_uuid();
  ts_fund uuid; af_fund uuid; ts_bm uuid; ts_vp uuid;
  o_kl uuid; o_kw uuid; o_bl uuid; o_bw uuid;       -- Fundation: Kies LKW, Kies LW, Beton LKW, Beton LW
  o_bmp uuid; o_bml uuid; o_v1 uuid; o_v2 uuid;     -- Betonmauer gepumpt/LW, Verputzen 1/2 seitig
  o_am uuid; o_as uuid; o_al uuid;                 -- Aushub Baumaschinen M, S, L
  pool_sb uuid;
  rr int; rec record; g text; oid uuid; sz text;
  verw_kies jsonb; verw_beton jsonb; verw_putz jsonb;
  af_nat uuid; ts_nat uuid; af_k uuid; ts_k uuid; af_sb uuid; ts_sb uuid;
  a_kies uuid; a_polier uuid; a_gart uuid;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into pool_ot from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  if ot is null or pool_ot is null then raise exception 'Vorlage Mauern/Pool nicht gefunden'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer') then raise exception 'Natursteinmauer gibt es schon - nichts geaendert.'; end if;

  -- ---------------------------------------------------------------- 1. Artikel
  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values
   (a_w, kg, 'material', 'KNECHT_PLASSELB_01', 'PLASSELB_01', 'Plasselb Natursteinblöcke 50-100 L (Wechselschicht)', 't', 180, 240, 'CHF', 1, 8.1, false, false, false, true, false),
   (a_s, kg, 'material', 'KNECHT_PLASSELB_02', 'PLASSELB_02', 'Plasselb Natursteinblöcke 300-500 L (Schichten)',      't', 180, 240, 'CHF', 1, 8.1, false, false, false, true, false),
   (a_t, kg, 'logistik', 'KNECHT_PLASSELB_03', 'PLASSELB_03', 'Transport Natursteine gekippt (Plasselb)',            't',  35,  45, 'CHF', 1, 8.1, false, false, false, true, false);

  -- ---------------------------------------------------------------- Ids der Vorlage
  select id into ef_nat from eingabefeld where offertentyp_id = ot and name = 'Fundation' and ist_tabelle;
  select id into ef_bl  from eingabefeld where offertentyp_id = ot and name = 'Blendmauer' and ist_tabelle;
  select id into sp_l from eingabefeld_tabelle_spalte where eingabefeld_id = ef_nat and name = 'Länge';
  select id into sp_b from eingabefeld_tabelle_spalte where eingabefeld_id = ef_nat and name = 'Breite';
  select id into sp_t from eingabefeld_tabelle_spalte where eingabefeld_id = ef_nat and name = 'Tiefe';
  select id into sp_v from eingabefeld_tabelle_spalte where eingabefeld_id = ef_nat and name = 'Volumen';
  select id into sp_bl_fb from eingabefeld_tabelle_spalte where eingabefeld_id = ef_bl and name = 'Fundamentbeton';
  select id into sp_bl_fl from eingabefeld_tabelle_spalte where eingabefeld_id = ef_bl and name = 'Fläche';
  select id into t_afk  from term where offertentyp_id = ot and name = 'Auflockerungsfaktor';
  select id into t_val  from term where offertentyp_id = ot and name = 'Volumen Aushub locker';
  select id into t_wand from term where offertentyp_id = ot and name = 'Wandbeton Blendmauer';
  select a.id into as_fund  from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Fundation';
  select a.id into as_blend from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Blendmauer';
  select a.id into as_aush  from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Aushub';
  select ts.id into ts_fund from teilschritt ts where ts.arbeitsschritt_id = as_fund limit 1;
  select af.id into af_fund from auswahlfeld af where af.teilschritt_id = ts_fund limit 1;
  select o.id into o_kl from auswahloption o where o.auswahlfeld_id = af_fund and o.name = 'Fundation Kieseinbau LKW';
  select o.id into o_kw from auswahloption o where o.auswahlfeld_id = af_fund and o.name = 'Fundation Kieseinbau Lieferwagen';
  select o.id into o_bmp from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_blend and o.name = 'Betonmauer gepumpt';
  select o.id into o_bml from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_blend and o.name = 'Betonmauer mit Lieferwagen';
  select o.id into o_v1 from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_blend and o.name = 'Verputzen einseitig';
  select o.id into o_v2 from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_blend and o.name = 'Verputzen zweiseitig';
  select ts.id into ts_bm from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption o on o.auswahlfeld_id = af.id where o.id = o_bmp;
  select ts.id into ts_vp from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption o on o.auswahlfeld_id = af.id where o.id = o_v1;
  select o.id into o_am from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_aush and o.name = 'Baumaschinen M';
  select o.id into o_as from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_aush and o.name = 'Baumaschinen S';
  select o.id into o_al from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_aush and o.name = 'Baumaschinen L';
  select o.id into pool_sb from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = pool_ot and ts.name ilike '%hinterf%' and o.name = 'Sickerbeton';
  select id into a_kies from artikel where bezeichnung = 'Kiesgemisch 0/45 mm Dmax 90 mm' limit 1;
  if ef_nat is null or ef_bl is null or sp_l is null or sp_b is null or sp_t is null or sp_v is null or sp_bl_fb is null or sp_bl_fl is null
     or t_afk is null or t_val is null or t_wand is null or as_fund is null or as_blend is null or as_aush is null or o_kl is null or o_kw is null
     or o_bmp is null or o_bml is null or o_v1 is null or o_v2 is null or o_am is null or o_as is null or o_al is null or pool_sb is null or a_kies is null then
    raise exception 'Grundlage der Vorlage nicht wie erwartet gefunden - nichts geaendert.';
  end if;

  -- ---------------------------------------------------------------- 2. Tabelle + Formeln
  update eingabefeld set name = 'Natursteinmauer' where id = ef_nat;
  update eingabefeld_tabelle_spalte set name = 'Fundamentbreite' where id = sp_b;
  update eingabefeld_tabelle_spalte set name = 'Fundamenttiefe'  where id = sp_t;

  select to_jsonb(t) into tmpl from term t where t.id = t_afk;
  for rec in select * from (values
      (t_zus, 'Aushubzuschlag pro Seite', 'konstante', 'm', 0.3),
      (t_tpm, 'Tonnen pro m² Mauer', 'konstante', 't/m²', 1)) as v(id, name, typ, einheit, wert) loop
    insert into term select * from jsonb_populate_record(null::term, tmpl || jsonb_build_object('id', rec.id, 'name', rec.name, 'typ', rec.typ, 'einheit', rec.einheit, 'wert', rec.wert, 'ausdruck', null,
        'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot)));
  end loop;

  select to_jsonb(s) into tmpl from eingabefeld_tabelle_spalte s where s.id = sp_l;
  for rec in select * from (values
      (sp_h,  'Höhe',           'm',  2, false, null::jsonb, null::numeric),
      (sp_hb, 'Hinterfüllbreite','m', 5, false, null::jsonb, null::numeric),
      (sp_lz, 'Länge mit Zuschlag', 'm', 6, true,
         pg_temp.f_add(pg_temp.f_ref('spalte', sp_l),
           pg_temp.f_mul(pg_temp.f_mul(pg_temp.f_ceil(pg_temp.f_div(pg_temp.f_ref('spalte', sp_l), pg_temp.f_add(pg_temp.f_ref('spalte', sp_l), pg_temp.f_lit(0.000001)))), pg_temp.f_lit(2)), pg_temp.f_ref('term', t_zus))), null::numeric),
      (sp_fl, 'Fläche',         'm²', 7, true, pg_temp.f_mul(pg_temp.f_ref('spalte', sp_l), pg_temp.f_ref('spalte', sp_h)), null::numeric),
      (sp_gw, 'Gewicht',        't',  8, true, pg_temp.f_mul(pg_temp.f_ref('spalte', sp_fl), pg_temp.f_ref('term', t_tpm)), null::numeric),
      (sp_hv, 'Hinterfüllvolumen', 'm³', 10, true,
         pg_temp.f_mul(pg_temp.f_mul(pg_temp.f_ref('spalte', sp_hb), pg_temp.f_ref('spalte', sp_h)), pg_temp.f_ref('spalte', sp_lz)), null::numeric)
    ) as v(id, name, einheit, reihenfolge, berechnet, ausdruck, vorschlag) loop
    insert into eingabefeld_tabelle_spalte select * from jsonb_populate_record(null::eingabefeld_tabelle_spalte,
      tmpl || jsonb_build_object('id', rec.id, 'eingabefeld_id', ef_nat, 'name', rec.name, 'einheit', rec.einheit, 'reihenfolge', rec.reihenfolge,
        'ist_berechnung', rec.berechnet, 'ausdruck', rec.ausdruck, 'vorschlagswert', rec.vorschlag, 'zusatztext_moeglich', false, 'flaechenformel_moeglich', false,
        'formel_modus', 'baukasten', 'formel_text', null, 'formel_baukasten_ausdruck', null, 'ist_dropdown', false, 'dropdown_leer_label', null, 'dropdown_pflicht', false, 'ausgeblendet', false));
  end loop;
  -- Fundamentvolumen jetzt mit Zuschlag auf der Länge
  update eingabefeld_tabelle_spalte
     set reihenfolge = 9, name = 'Volumen', einheit = 'm³',
         ausdruck = pg_temp.f_mul(pg_temp.f_mul(pg_temp.f_ref('spalte', sp_lz), pg_temp.f_ref('spalte', sp_b)), pg_temp.f_ref('spalte', sp_t))
   where id = sp_v;
  update eingabefeld_tabelle_spalte set reihenfolge = 1 where id = sp_l;
  update eingabefeld_tabelle_spalte set reihenfolge = 3 where id = sp_b;
  update eingabefeld_tabelle_spalte set reihenfolge = 4 where id = sp_t;
  update eingabefeld_tabelle_spalte set ausgeblendet = true where eingabefeld_id = ef_nat and ist_berechnung;

  select to_jsonb(t) into tmpl from term t where t.name = 'Fläche Blendmauer' and t.offertentyp_id = ot;
  insert into term select * from jsonb_populate_record(null::term, tmpl || jsonb_build_object('id', t_gew, 'name', 'Gewicht Natursteinmauer', 'einheit', 't', 'ausdruck', pg_temp.f_ref('spalte', sp_gw), 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot)));
  insert into term select * from jsonb_populate_record(null::term, tmpl || jsonb_build_object('id', t_hf, 'name', 'Hinterfüllvolumen Natursteinmauer', 'einheit', 'm³', 'ausdruck', pg_temp.f_ref('spalte', sp_hv), 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot)));
  insert into term select * from jsonb_populate_record(null::term, tmpl || jsonb_build_object('id', t_hl, 'name', 'Hinterfüllvolumen lose', 'einheit', 'm³', 'ausdruck', pg_temp.f_mul(pg_temp.f_ref('term', t_hf), pg_temp.f_ref('term', t_afk)), 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot)));

  -- ---------------------------------------------------------------- 3. Fundation
  verw_kies  := jsonb_build_array(jsonb_build_object('eingabefeld_id', ef_nat, 'spalte_id', sp_v, 'gruppe', 'fundation'));
  verw_beton := jsonb_build_array(jsonb_build_object('eingabefeld_id', ef_nat, 'spalte_id', sp_v, 'gruppe', 'fundation'),
                                  jsonb_build_object('eingabefeld_id', ef_bl,  'spalte_id', sp_bl_fb, 'gruppe', 'fundation'));
  -- Kies-Optionen: Menge pro m3 Fundamentvolumen (Auflockerung statt "Volumen Aushub locker")
  update ressourcenzeile set menge_ausdruck = replace(menge_ausdruck::text, t_val::text, t_afk::text)::jsonb where option_id in (o_kl, o_kw);
  update auswahloption set name = 'Kies LKW', tabellenverweis = verw_kies, mehrfachauswahl = true, reihenfolge = 1 where id = o_kl;
  update auswahloption set name = 'Kies Lieferwagen', tabellenverweis = verw_kies, mehrfachauswahl = true, reihenfolge = 2 where id = o_kw;

  -- Beton-Optionen aus der bisherigen Betonmauer ableiten (Fundament-Anteile)
  select to_jsonb(o) into j from auswahloption o where o.id = o_kl;
  o_bl := gen_random_uuid(); o_bw := gen_random_uuid();
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j || jsonb_build_object('id', o_bl, 'name', 'Beton LKW gepumpt', 'reihenfolge', 3,
      'beschreibung', 'Fundament mit gepumptem Beton erstellen.', 'tabellenverweis', verw_beton, 'mehrfachauswahl', true, 'mengenoption', false));
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j || jsonb_build_object('id', o_bw, 'name', 'Beton Lieferwagen', 'reihenfolge', 4,
      'beschreibung', 'Fundament mit Beton aus dem Betonwerk (Lieferwagen) erstellen.', 'tabellenverweis', verw_beton, 'mehrfachauswahl', true, 'mengenoption', false));
  -- gepumpt: Personal 3 Std je m3, Betonpumpe, Beton-Transport, SVB, Restbeton, Schmiermischung
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), o_bl, 1, pg_temp.f_lit(3));
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, 'Gartenarbeiter'), o_bl, 2, pg_temp.f_lit(3));
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, '#staffel'), o_bl, 3, pg_temp.f_lit(1));
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, 'Beton-Transport'), o_bl, 4, pg_temp.f_lit(1));
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, 'SVB Beton'), o_bl, 5, pg_temp.f_lit(1), 10);
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, 'Restbeton- und Reinigungswasserentsorgung'), o_bl, 6, pg_temp.f_lit(1), null, true);
  perform pg_temp.klon(pg_temp.rz_id(o_bmp, 'Pump-Schmiermischung, 400 kg/m3, 0–4 mm'), o_bl, 7, pg_temp.f_lit(1), null, true);
  -- Lieferwagen: Personal 3 Std je m3, SVB, Chauffeur + Lieferwagentransport (4 Fahrten je m3)
  perform pg_temp.klon(pg_temp.rz_id(o_bml, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), o_bw, 1, pg_temp.f_lit(3));
  perform pg_temp.klon(pg_temp.rz_id(o_bml, 'Gartenarbeiter'), o_bw, 2, pg_temp.f_lit(3));
  perform pg_temp.klon(pg_temp.rz_id(o_bml, 'SVB Beton'), o_bw, 3, pg_temp.f_lit(1), 10);
  perform pg_temp.klon(pg_temp.rz_id(o_bml, 'Lieferwagenchauffeur Pool Kieswerk/Betonwerk'), o_bw, 4, pg_temp.f_lit(4));
  perform pg_temp.klon(pg_temp.rz_id(o_bml, 'Lieferwagentransport Kieswerk/Betonwerk'), o_bw, 5, pg_temp.f_lit(4));

  -- ---------------------------------------------------------------- 4. Betonmauer: nur noch Wand
  update ressourcenzeile set menge_ausdruck = pg_temp.f_mul(pg_temp.f_ref('term', (select id from term where offertentyp_id = ot and name = 'Fläche Blendmauer')), pg_temp.f_lit(1.1))
   where option_id in (o_bmp, o_bml) and id in (pg_temp.rz_id(o_bmp, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), pg_temp.rz_id(o_bmp, 'Gartenarbeiter'),
                                                 pg_temp.rz_id(o_bml, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), pg_temp.rz_id(o_bml, 'Gartenarbeiter'));
  delete from ressourcenzeile where id in (pg_temp.rz_id(o_bmp, 'SVB Beton'), pg_temp.rz_id(o_bml, 'SVB Beton'));
  update ressourcenzeile set menge_ausdruck = pg_temp.f_ref('term', t_wand) where id in (pg_temp.rz_id(o_bmp, 'Beton-Transport'), pg_temp.rz_id(o_bmp, '#staffel'));
  update ressourcenzeile set menge_ausdruck = pg_temp.f_mul(pg_temp.f_ref('term', t_wand), pg_temp.f_lit(4))
   where id in (pg_temp.rz_id(o_bml, 'Lieferwagenchauffeur Pool Kieswerk/Betonwerk'), pg_temp.rz_id(o_bml, 'Lieferwagentransport Kieswerk/Betonwerk'));
  update auswahloption set beschreibung = 'Betonmauer mit gepumptem Beton erstellen.' where id = o_bmp;
  update auswahloption set beschreibung = 'Betonmauer mit Beton aus dem Betonwerk (Lieferwagen) erstellen.' where id = o_bml;
  update teilschritt set name = 'Betonmauer' where id = ts_bm;
  update auswahlfeld set name = 'Betonmauer' where teilschritt_id = ts_bm;
  update arbeitsschritt set name = 'Verblendmauer (Coffra)' where id = as_blend;

  -- ---------------------------------------------------------------- 5. Verputzen mit Tabellenverweis
  verw_putz := jsonb_build_array(jsonb_build_object('eingabefeld_id', ef_bl, 'spalte_id', sp_bl_fl, 'gruppe', 'verputzen'));
  for rec in select * from (values (o_v1, 1), (o_v2, 2)) as v(id, seiten) loop
    update auswahloption set tabellenverweis = verw_putz, mehrfachauswahl = true, mengenoption = false where id = rec.id;
    update ressourcenzeile set menge_ausdruck = pg_temp.f_lit(0.65 * rec.seiten) where option_id = rec.id and kategorie = 'personal';
    update ressourcenzeile set menge_ausdruck = pg_temp.f_div(pg_temp.f_lit(rec.seiten), pg_temp.f_lit(7))
     where id = pg_temp.rz_id(rec.id, 'PCI Pericret Ausgleichsmörtel 25kg');
    update ressourcenzeile set mengenoption_ausgenommen = true where option_id = rec.id and kategorie = 'material' and id <> pg_temp.rz_id(rec.id, 'PCI Pericret Ausgleichsmörtel 25kg');
  end loop;

  -- ---------------------------------------------------------------- Arbeitsschritt-Reihenfolge
  update arbeitsschritt set reihenfolge = 1 where offertentyp_id = ot and name = 'Vorarbeiten';
  update arbeitsschritt set reihenfolge = 2 where id = as_aush;
  update arbeitsschritt set reihenfolge = 3 where id = as_fund;
  update arbeitsschritt set reihenfolge = 6 where id = as_blend;

  -- ---------------------------------------------------------------- 6. Natursteinmauer
  select to_jsonb(a) into tmpl from arbeitsschritt a where a.id = as_aush;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, tmpl || jsonb_build_object('id', as_nat, 'name', 'Natursteinmauer', 'reihenfolge', 4));
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, tmpl || jsonb_build_object('id', as_hin, 'name', 'Hinterfüllung', 'reihenfolge', 5));

  ts_nat := gen_random_uuid(); af_nat := gen_random_uuid();
  select to_jsonb(ts) into tmpl from teilschritt ts where ts.id = ts_fund;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_nat, 'arbeitsschritt_id', as_nat, 'name', 'Natursteinmauer Plasselb Wechselschicht', 'reihenfolge', 1, 'beschreibung', null));
  select to_jsonb(af) into tmpl from auswahlfeld af where af.id = af_fund;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_nat, 'teilschritt_id', ts_nat, 'name', 'Natursteinmauer Plasselb Wechselschicht'));

  select id into a_polier from artikel where bezeichnung = 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00' limit 1;
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_am;
  rr := 0;
  for rec in select * from (values
      ('von Hand',   null, null, 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband von Hand setzen.'),
      ('Maschine S', 'Raupenbagger S', 'Raupendumper S', 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband mit Maschine S setzen.'),
      ('Maschine M', 'Raupenbagger M', 'Raupendumper M', 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband mit Maschine M setzen.'),
      ('Maschine L', 'Raupenbagger L', '(Raupen-) Dumper L', 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband mit Maschine L setzen.')
    ) as v(name, bagger, dumper, beschr) loop
    rr := rr + 1; oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', af_nat, 'name', rec.name, 'reihenfolge', rr,
        'beschreibung', rec.beschr, 'mengenoption', false, 'mehrfachauswahl', false, 'tabellenverweis', null, 'hinweistext', null, 'hinweisbild_url', null));
    perform pg_temp.klon(pg_temp.rz_id(o_am, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), oid, 1, pg_temp.f_mul(pg_temp.f_ref('term', t_gew), pg_temp.f_lit(4.5)));
    perform pg_temp.klon(pg_temp.rz_id(o_am, 'Gartenarbeiter'), oid, 2, pg_temp.f_mul(pg_temp.f_ref('term', t_gew), pg_temp.f_lit(4.5)));
    -- Stein + Transport: Zeilen von der Kies-Option (Material/Logistik) kopieren, Artikel austauschen
    perform pg_temp.klon(pg_temp.rz_id(o_kl, 'Kiesgemisch 0/45 mm Dmax 90 mm'), oid, 3, pg_temp.f_ref('term', t_gew), null, false, a_w);
    perform pg_temp.klon(pg_temp.rz_id(o_kl, 'Kiesgemisch 0/45 mm Dmax 90 mm'), oid, 4, pg_temp.f_ref('term', t_gew), null, false, a_t);
    if rec.bagger is not null then
      perform pg_temp.klon(pg_temp.rz_id(case rec.name when 'Maschine S' then o_as when 'Maschine M' then o_am else o_al end, rec.bagger), oid, 5, pg_temp.f_mul(pg_temp.f_ref('term', t_gew), pg_temp.f_lit(2.7)));
      perform pg_temp.klon(pg_temp.rz_id(case rec.name when 'Maschine S' then o_as when 'Maschine M' then o_am else o_al end, rec.dumper), oid, 6, pg_temp.f_mul(pg_temp.f_ref('term', t_gew), pg_temp.f_lit(2.7)));
    end if;
  end loop;
  -- Transportzeile ist Logistik, nicht Material
  update ressourcenzeile set kategorie = 'logistik' where option_id in (select id from auswahloption where auswahlfeld_id = af_nat) and artikel_id = a_t;

  -- ---------------------------------------------------------------- 7. Hinterfüllung
  ts_k := gen_random_uuid(); af_k := gen_random_uuid(); ts_sb := gen_random_uuid(); af_sb := gen_random_uuid();
  select to_jsonb(ts) into tmpl from teilschritt ts where ts.id = ts_fund;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_k,  'arbeitsschritt_id', as_hin, 'name', 'Hinterfüllung Kies', 'reihenfolge', 1, 'beschreibung', null));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_sb, 'arbeitsschritt_id', as_hin, 'name', 'Hinterfüllung Sickerbeton', 'reihenfolge', 2, 'beschreibung', null));
  select to_jsonb(af) into tmpl from auswahlfeld af where af.id = af_fund;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_k,  'teilschritt_id', ts_k,  'name', 'Hinterfüllung Kies'));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_sb, 'teilschritt_id', ts_sb, 'name', 'Hinterfüllung Sickerbeton'));

  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_am;
  rr := 0;
  for rec in select * from (values
      (af_k,  'Kies LKW, Maschine S',        'k', 'lkw', 'S'),
      (af_k,  'Kies LKW, Maschine M',        'k', 'lkw', 'M'),
      (af_k,  'Kies LKW, Maschine L',        'k', 'lkw', 'L'),
      (af_k,  'Kies Lieferwagen, Maschine S','k', 'lw',  'S'),
      (af_sb, 'Sickerbeton LKW, Maschine S', 's', 'lkw', 'S'),
      (af_sb, 'Sickerbeton LKW, Maschine M', 's', 'lkw', 'M'),
      (af_sb, 'Sickerbeton LKW, Maschine L', 's', 'lkw', 'L')
    ) as v(af, name, mat, transport, groesse) loop
    rr := rr + 1; oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', rec.af, 'name', rec.name, 'reihenfolge', rr,
        'beschreibung', case rec.mat when 'k' then 'Hinterfüllung mit Kies liefern, einbauen und verdichten.' else 'Hinterfüllung mit Sickerbeton liefern und einbauen.' end,
        'mengenoption', false, 'mehrfachauswahl', false, 'tabellenverweis', null, 'hinweistext', null, 'hinweisbild_url', null));
    sz := rec.groesse;
    -- Personal + Maschinen wie beim Aushub (S 0.8/0.45, M 0.6/0.35, L 0.4/0.25 je m3)
    perform pg_temp.klon(pg_temp.rz_id(o_am, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), oid, 1,
      pg_temp.f_mul(pg_temp.f_ref('term', case rec.mat when 'k' then t_hl else t_hf end), pg_temp.f_lit(case sz when 'S' then 0.8 when 'M' then 0.6 else 0.4 end)));
    perform pg_temp.klon(pg_temp.rz_id(o_am, 'Gartenarbeiter'), oid, 2,
      pg_temp.f_mul(pg_temp.f_ref('term', case rec.mat when 'k' then t_hl else t_hf end), pg_temp.f_lit(case sz when 'S' then 0.8 when 'M' then 0.6 else 0.4 end)));
    perform pg_temp.klon(pg_temp.rz_id(case sz when 'S' then o_as when 'M' then o_am else o_al end, case sz when 'S' then 'Raupenbagger S' when 'M' then 'Raupenbagger M' else 'Raupenbagger L' end), oid, 3,
      pg_temp.f_mul(pg_temp.f_ref('term', case rec.mat when 'k' then t_hl else t_hf end), pg_temp.f_lit(case sz when 'S' then 0.45 when 'M' then 0.35 else 0.25 end)));
    perform pg_temp.klon(pg_temp.rz_id(case sz when 'S' then o_as when 'M' then o_am else o_al end, case sz when 'S' then 'Raupendumper S' when 'M' then 'Raupendumper M' else '(Raupen-) Dumper L' end), oid, 4,
      pg_temp.f_mul(pg_temp.f_ref('term', case rec.mat when 'k' then t_hl else t_hf end), pg_temp.f_lit(case sz when 'S' then 0.45 when 'M' then 0.35 else 0.25 end)));
    if rec.mat = 'k' then
      perform pg_temp.klon(pg_temp.rz_id(o_kl, 'Kiesgemisch 0/45 mm Dmax 90 mm'), oid, 5, pg_temp.f_ref('term', t_hl), null);
      if rec.transport = 'lkw' then
        perform pg_temp.klon(pg_temp.rz_id(o_kl, 'Kies-Transport'), oid, 6, pg_temp.f_ref('term', t_hl));
      else
        perform pg_temp.klon(pg_temp.rz_id(o_kw, 'Lieferwagenchauffeur Pool Kieswerk/Betonwerk'), oid, 6, pg_temp.f_mul(pg_temp.f_mul(pg_temp.f_ref('term', t_hl), pg_temp.f_lit(0.75)), pg_temp.f_lit(2)));
        perform pg_temp.klon(pg_temp.rz_id(o_kw, 'Lieferwagentransport Kieswerk/Betonwerk'), oid, 7, pg_temp.f_mul(pg_temp.f_mul(pg_temp.f_ref('term', t_hl), pg_temp.f_lit(0.75)), pg_temp.f_lit(2)));
      end if;
    else
      perform pg_temp.klon(pg_temp.rz_id(pool_sb, 'Sickerbeton, 250 kg/m3, 16–32 mm / 32–45 mm'), oid, 5, pg_temp.f_ref('term', t_hf), 15);
      perform pg_temp.klon(pg_temp.rz_id(pool_sb, 'Beton-Transport'), oid, 6, pg_temp.f_ref('term', t_hf));
    end if;
  end loop;
  -- Reihenfolge der Buttons je Feld ab 1
  update auswahloption o set reihenfolge = x.rn from (select id, row_number() over (partition by auswahlfeld_id order by reihenfolge, name) rn from auswahloption where auswahlfeld_id in (af_k, af_sb)) x where x.id = o.id;

  raise notice 'Natursteinmauer/Hinterfüllung/Fundation fertig.';
end $$;
