-- ============================================================================
-- Verblendmauer: Arbeitsschritt "Verblender" (Z-Elemente, Geopietra, Ecken, Abdeckplatte, Stirnseiten)
--  Artikel: Stonepanel Rusted Grey/Brown (Knechtgarten), Geopietra Toce/Cascata + Zubehör (HGC, Preise April 2024,
--  VK = EK x 1.4), Multiment/Adheaseal (Knechtgarten, vorläufig), Stirnblech Corten/Anthrazit (Grütter).
--  Blendmauer-Tabelle: neue Eingaben Verblender-Seiten, Abdeckung (m), Stirnseiten, Ecken (m);
--  Rechenspalten Verblenderfläche, Stirnlänge (ausgeblendet).
--  Verblender Z/Geopietra: Tabellenverweis (Gruppe "verblender") auf Verblenderfläche; Rest ohne Verweis.
-- Werte aus dem Berechnungstool (Blatt Verblendmauer) und den HGC-Rechnungen.
-- ============================================================================
create or replace function pg_temp.f_ref(art text, id uuid) returns jsonb language sql as $$ select jsonb_build_object('id', id, 'ref', art) $$;
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.f_mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','*','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_ceil(a jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','ceil','args', jsonb_build_array(a)) $$;

create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz left join artikel a on a.id = rz.artikel_id
   where rz.option_id = p_opt and a.bezeichnung = p_art order by rz.reihenfolge, rz.id limit 1 $$;

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

create or replace function pg_temp.neuer_artikel(p_lief uuid, p_kat text, p_nr text, p_bez text, p_einheit text, p_ep numeric) returns uuid language plpgsql as $$
declare nid uuid := gen_random_uuid();
begin
  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values (nid, p_lief, p_kat, 'KNECHT_' || p_nr, p_nr, p_bez, p_einheit, p_ep, round(p_ep * 1.4, 2), 'CHF', 1, 8.1, false, false, false, true, false);
  return nid;
end $$;

do $$
declare
  ot uuid; kg uuid := 'db9c6bd1-ee9d-40a4-9d1f-723faba51728'; hgc uuid; gru uuid;
  ef uuid; sp_h uuid; sp_fl uuid; tmpl jsonb;
  sp_seiten uuid := gen_random_uuid(); sp_abd uuid := gen_random_uuid(); sp_stirn uuid := gen_random_uuid(); sp_eck uuid := gen_random_uuid();
  sp_vfl uuid := gen_random_uuid(); sp_stl uuid := gen_random_uuid(); sp_ho uuid;
  t_abd uuid := gen_random_uuid(); t_stl uuid := gen_random_uuid(); t_eck uuid := gen_random_uuid(); t_ref jsonb;
  a_zg uuid; a_zb uuid; a_mult uuid; a_adh uuid; a_toce uuid; a_casc uuid; a_eck_t uuid; a_eck_c uuid; a_abd uuid; a_small uuid; a_big uuid; a_coll uuid; a_farb uuid;
  a_corten uuid; a_anth uuid; a_mont uuid; a_pias uuid;
  as_bl uuid; as_v uuid := gen_random_uuid(); ts_vp uuid; af_vp uuid; o_v1 uuid; o_pol uuid; rr int; rec record; oid uuid; ts_n uuid; af_n uuid; verw jsonb; src_pol uuid; src_gar uuid; src_mat uuid; n int;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into hgc from lieferant where name = 'HG Commerciale';
  select id into gru from lieferant where name = 'Grütter Metallwaren AG';
  select id into ef from eingabefeld where offertentyp_id = ot and name = 'Blendmauer' and ist_tabelle;
  select id into sp_h from eingabefeld_tabelle_spalte where eingabefeld_id = ef and name = 'Höhe';
  select id into sp_fl from eingabefeld_tabelle_spalte where eingabefeld_id = ef and name = 'Fläche';
  select id into as_bl from arbeitsschritt where offertentyp_id = ot and name = 'Verblendmauer (Coffra)';
  select o.id, af.id, ts.id into o_v1, af_vp, ts_vp from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
   where ts.arbeitsschritt_id = as_bl and o.name = 'Verputzen einseitig';
  select id into a_pias from artikel where bezeichnung = 'Platten Piazentina geflammt FL 40/3cm' limit 1;
  if hgc is null or gru is null or ef is null or sp_h is null or sp_fl is null or as_bl is null or o_v1 is null or a_pias is null then raise exception 'Grundlage nicht gefunden - nichts geaendert.'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Verblender') then raise exception 'Verblender gibt es schon'; end if;

  -- ------------------------------------------------------------ Artikel
  a_zg    := pg_temp.neuer_artikel(kg,  'material', 'VERBLENDER_01', 'Verblender Stonepanel Rusted Grey (Z-Element 20x60 cm)',  'm²', 89.30);
  a_zb    := pg_temp.neuer_artikel(kg,  'material', 'VERBLENDER_02', 'Verblender Stonepanel Rusted Brown (Z-Element 20x60 cm)', 'm²', 89.30);
  update artikel set vp_knecht = 105 where id in (a_zg, a_zb);
  a_mult  := pg_temp.neuer_artikel(kg,  'material', 'VERBLENDER_03', 'Natursteinkleber Multiment 25 kg', 'Sack', 41);
  a_adh   := pg_temp.neuer_artikel(kg,  'material', 'VERBLENDER_04', 'Fugenmaterial Adheaseal', 'Karton', 29.75);
  a_toce  := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_TOCE', 'Geopietra Toce PP19 Mauerverblender 40-50 mm', 'm²', 128.50);
  a_casc  := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_CASCATA', 'Geopietra Cascata P06 Mauerverblender', 'm²', 128.50);
  a_eck_t := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_ECKE_TOCE', 'Geopietra Toce Ecken', 'm', 72.90);
  a_eck_c := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_ECKE_CASCATA', 'Geopietra Cascata Ecken', 'm', 72.90);
  a_abd   := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_ABDECKUNG', 'Geopietra Abdeckung 36x100 cm', 'Stk', 74);
  a_small := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_GEOFIT_SMALL', 'Geopietra GeoFit Small 100 Stück', 'Karton', 63.90);
  a_big   := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_GEOFIT_BIG', 'Geopietra GeoFit Big 50 Stück', 'Karton', 63.90);
  a_coll  := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_GEOCOLL', 'Geopietra CX geocoll Klebe- und Armiermörtel 25 kg', 'Sack', 31.90);
  a_farb  := pg_temp.neuer_artikel(hgc, 'material', 'GEOPIETRA_FARBPULVER', 'Geopietra CX-CM Farbpulver', 'Stk', 11.40);
  a_corten:= pg_temp.neuer_artikel(gru, 'material', 'STIRNVERBLENDUNG_CORTEN', 'Stirnverblendung Verblendmauer Cortenstahl (max 30 cm breit)', 'm', 26);
  a_anth  := pg_temp.neuer_artikel(gru, 'material', 'STIRNVERBLENDUNG_ANTHRAZIT', 'Stirnverblendung Verblendmauer Blech Anthrazit (max 30 cm breit)', 'm', 84);
  a_mont  := pg_temp.neuer_artikel(gru, 'material', 'STIRNVERBLENDUNG_MONTAGE', 'Montagematerial Stirnverblendung', 'Stk', 10);

  -- ------------------------------------------------------------ Tabelle Blendmauer
  select to_jsonb(s) into tmpl from eingabefeld_tabelle_spalte s where s.id = sp_h;
  -- bestehende Rechenspalten nach hinten schieben, damit die neuen Eingaben vor den Rechenspalten stehen
  update eingabefeld_tabelle_spalte set reihenfolge = reihenfolge + 4 where eingabefeld_id = ef and reihenfolge >= 5;
  for rec in select * from (values
      (sp_seiten, 'Verblender-Seiten', 'Stk', 5, false, null::jsonb, 1::numeric),
      (sp_abd,    'Abdeckung',         'm',   6, false, null::jsonb, null::numeric),
      (sp_stirn,  'Stirnseiten',       'Stk', 7, false, null::jsonb, null::numeric),
      (sp_eck,    'Ecken',             'm',   8, false, null::jsonb, null::numeric)
    ) as v(id, name, einheit, reihenfolge, berechnet, ausdruck, vorschlag) loop
    insert into eingabefeld_tabelle_spalte select * from jsonb_populate_record(null::eingabefeld_tabelle_spalte,
      tmpl || jsonb_build_object('id', rec.id, 'eingabefeld_id', ef, 'name', rec.name, 'einheit', rec.einheit, 'reihenfolge', rec.reihenfolge,
        'ist_berechnung', false, 'ausdruck', null, 'vorschlagswert', rec.vorschlag, 'ausgeblendet', false));
  end loop;
  select max(reihenfolge) into rr from eingabefeld_tabelle_spalte where eingabefeld_id = ef;
  for rec in select * from (values
      (sp_vfl, 'Verblenderfläche', 'm²', rr + 1, pg_temp.f_mul(pg_temp.f_ref('spalte', sp_fl), pg_temp.f_ref('spalte', sp_seiten))),
      (sp_stl, 'Stirnlänge',       'm',  rr + 2, pg_temp.f_mul(pg_temp.f_mul(pg_temp.f_ref('spalte', sp_stirn), pg_temp.f_ref('spalte', sp_h)), pg_temp.f_lit(1.1)))
    ) as v(id, name, einheit, reihenfolge, ausdruck) loop
    insert into eingabefeld_tabelle_spalte select * from jsonb_populate_record(null::eingabefeld_tabelle_spalte,
      tmpl || jsonb_build_object('id', rec.id, 'eingabefeld_id', ef, 'name', rec.name, 'einheit', rec.einheit, 'reihenfolge', rec.reihenfolge,
        'ist_berechnung', true, 'ausdruck', rec.ausdruck, 'vorschlagswert', null, 'ausgeblendet', true));
  end loop;

  -- Summen-Terms
  select to_jsonb(t) into tmpl from term t where t.offertentyp_id = ot and t.name = 'Fläche Blendmauer';
  for rec in select * from (values (t_abd, 'Abdeckung Blendmauer', 'm', sp_abd), (t_stl, 'Stirnlänge Blendmauer', 'm', sp_stl), (t_eck, 'Ecken Blendmauer', 'm', sp_eck)) as v(id, name, einheit, sp) loop
    insert into term select * from jsonb_populate_record(null::term, tmpl || jsonb_build_object('id', rec.id, 'name', rec.name, 'einheit', rec.einheit,
      'ausdruck', pg_temp.f_ref('spalte', rec.sp), 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot)));
  end loop;

  -- ------------------------------------------------------------ Struktur
  select to_jsonb(a) into tmpl from arbeitsschritt a where a.id = as_bl;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, tmpl || jsonb_build_object('id', as_v, 'name', 'Verblender', 'reihenfolge', (select max(reihenfolge) + 1 from arbeitsschritt where offertentyp_id = ot)));

  src_pol := pg_temp.rz_id(o_v1, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00');
  src_gar := pg_temp.rz_id(o_v1, 'Gartenarbeiter');
  src_mat := pg_temp.rz_id(o_v1, 'PCI Pericret Ausgleichsmörtel 25kg');
  verw := jsonb_build_array(jsonb_build_object('eingabefeld_id', ef, 'spalte_id', sp_vfl, 'gruppe', 'verblender'));
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_v1;

  -- Teilschritte: Name, Optionen (Name, Beschreibung, mit Verweis?, Zeilen: Art (artikel, formel, versch))
  rr := 0;
  for rec in select * from (values
      (1, 'Verblender Z-Elemente',  'Z-Elemente Rusted Grey',  'Mauer mit Z-Element-Verblendern Stonepanel Rusted Grey liefern, zuschneiden und aufkleben.', true),
      (1, 'Verblender Z-Elemente',  'Z-Elemente Rusted Brown', 'Mauer mit Z-Element-Verblendern Stonepanel Rusted Brown liefern, zuschneiden und aufkleben.', true),
      (2, 'Verblender Geopietra',   'Geopietra Toce',          'Mauer mit Geopietra-Verblendern Toce liefern und aufkleben, Fugen mit GeoFit füllen.', true),
      (2, 'Verblender Geopietra',   'Geopietra Cascata',       'Mauer mit Geopietra-Verblendern Cascata liefern und aufkleben, Fugen mit GeoFit füllen.', true),
      (3, 'Geopietra Ecken',        'Ecken Toce',              'Geopietra-Eckelemente Toce setzen.', false),
      (3, 'Geopietra Ecken',        'Ecken Cascata',           'Geopietra-Eckelemente Cascata setzen.', false),
      (4, 'Abdeckplatte',           'Abdeckplatte Piasentina', 'Mauerabdeckung mit Piasentina-Platten erstellen.', false),
      (4, 'Abdeckplatte',           'Geopietra Abdeckung',     'Mauerabdeckung mit Geopietra-Abdeckplatten erstellen.', false),
      (5, 'Stirnseiten',            'Stirnseite Cortenblech',  'Stirnseiten mit Cortenstahl-Blech verblenden.', false),
      (5, 'Stirnseiten',            'Stirnseite Blech Anthrazit', 'Stirnseiten mit Blech anthrazit verblenden.', false)
    ) as v(tsn, ts_name, name, beschr, mit_verweis) loop
    -- Teilschritt/Auswahlfeld beim ersten Eintrag einer Gruppe anlegen
    select ts.id, af.id into ts_n, af_n from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id where ts.arbeitsschritt_id = as_v and ts.name = rec.ts_name;
    if ts_n is null then
      ts_n := gen_random_uuid(); af_n := gen_random_uuid();
      insert into teilschritt select * from jsonb_populate_record(null::teilschritt, (select to_jsonb(t) from teilschritt t where t.id = ts_vp) || jsonb_build_object('id', ts_n, 'arbeitsschritt_id', as_v, 'name', rec.ts_name, 'reihenfolge', rec.tsn, 'beschreibung', null));
      insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, (select to_jsonb(f) from auswahlfeld f where f.id = af_vp) || jsonb_build_object('id', af_n, 'teilschritt_id', ts_n, 'name', rec.ts_name));
      rr := 0;
    end if;
    rr := rr + 1; oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', af_n, 'name', rec.name, 'reihenfolge', rr,
        'beschreibung', rec.beschr, 'mengenoption', false, 'mehrfachauswahl', rec.mit_verweis, 'tabellenverweis', case when rec.mit_verweis then verw else null end, 'hinweistext', null, 'hinweisbild_url', null));

    -- Zeilen je Option
    if rec.name in ('Z-Elemente Rusted Grey', 'Z-Elemente Rusted Brown') then
      perform pg_temp.klon(src_pol, oid, 1, pg_temp.f_lit(1.4));
      perform pg_temp.klon(src_gar, oid, 2, pg_temp.f_lit(1.4));
      perform pg_temp.klon(src_mat, oid, 3, pg_temp.f_lit(1), case rec.name when 'Z-Elemente Rusted Grey' then a_zg else a_zb end);
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_lit(0.2), a_mult);   -- 5 kg/m2 = 0.2 Sack à 25 kg
    elsif rec.name in ('Geopietra Toce', 'Geopietra Cascata') then
      perform pg_temp.klon(src_pol, oid, 1, pg_temp.f_lit(2.8));
      perform pg_temp.klon(src_gar, oid, 2, pg_temp.f_lit(2.8));
      perform pg_temp.klon(src_mat, oid, 3, pg_temp.f_lit(1), case rec.name when 'Geopietra Toce' then a_toce else a_casc end);
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_lit(0.51), a_coll);   -- 18 Sack / 35 m2 (HGC-Rechnung 2024)
      perform pg_temp.klon(src_mat, oid, 5, pg_temp.f_lit(0.51), a_farb);
      perform pg_temp.klon(src_mat, oid, 6, pg_temp.f_lit(0.14), a_small);  -- 5 Karton / 35 m2
      perform pg_temp.klon(src_mat, oid, 7, pg_temp.f_lit(0.11), a_big);    -- 4 Karton / 35 m2
    elsif rec.name in ('Ecken Toce', 'Ecken Cascata') then
      perform pg_temp.klon(src_mat, oid, 1, pg_temp.f_ref('term', t_eck), case rec.name when 'Ecken Toce' then a_eck_t else a_eck_c end);
    elsif rec.name = 'Abdeckplatte Piasentina' then
      t_ref := pg_temp.f_ref('term', t_abd);
      perform pg_temp.klon(src_pol, oid, 1, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.55)));
      perform pg_temp.klon(src_gar, oid, 2, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.55)));
      perform pg_temp.klon(src_mat, oid, 3, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.4)), a_pias);          -- 40 cm breit
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.12)), a_mult);
      perform pg_temp.klon(src_mat, oid, 5, pg_temp.f_ceil(pg_temp.f_mul(t_ref, pg_temp.f_lit(0.1356))), a_adh);  -- 0.6 x 0.226 je m, aufgerundet
    elsif rec.name = 'Geopietra Abdeckung' then
      t_ref := pg_temp.f_ref('term', t_abd);
      perform pg_temp.klon(src_pol, oid, 1, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.55)));
      perform pg_temp.klon(src_gar, oid, 2, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.55)));
      perform pg_temp.klon(src_mat, oid, 3, t_ref, a_abd);                                               -- 1 Stk je m
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.12)), a_coll);
    elsif rec.name = 'Stirnseite Cortenblech' then
      t_ref := pg_temp.f_ref('term', t_stl);
      perform pg_temp.klon(src_pol, oid, 1, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.5)));
      perform pg_temp.klon(src_gar, oid, 2, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.5)));
      perform pg_temp.klon(src_mat, oid, 3, t_ref, a_corten);
      perform pg_temp.klon(src_mat, oid, 4, pg_temp.f_mul(t_ref, pg_temp.f_lit(5)), a_mont);
    elsif rec.name = 'Stirnseite Blech Anthrazit' then
      t_ref := pg_temp.f_ref('term', t_stl);
      perform pg_temp.klon(src_pol, oid, 1, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.5)));
      perform pg_temp.klon(src_gar, oid, 2, pg_temp.f_mul(t_ref, pg_temp.f_lit(0.5)));
      perform pg_temp.klon(src_mat, oid, 3, t_ref, a_anth);
      perform pg_temp.klon(src_mat, oid, 4, t_ref, a_mont);
    end if;
  end loop;
  select count(*) into n from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id where ts.arbeitsschritt_id = as_v;
  if n <> 10 then raise exception 'Erwartet 10 Optionen, angelegt %', n; end if;
  raise notice 'Verblender angelegt.';
end $$;
