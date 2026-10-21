-- ============================================================================
-- Natursteinmauer: Teilschritt "Zwischentransport Natursteine" (Steine ab Lager Knecht zur Baustelle)
--  Mulde LKW:    je 10 t eine Fuhre (Artikel 370 CHF je Fuhre) + 1.5 Std Polier und Gartenarbeiter je Fuhre
--  Lieferwagen:  1 Fahrt je Tonne (Hin- und Rückfahrt = 2 Strecken), Lieferwagen + Chauffeur ab Magazin
-- Werte aus dem Berechnungstool (Blatt Natursteinmauer: Zwischentransport Mulde / LW).
-- ============================================================================
create or replace function pg_temp.f_ref(art text, id uuid) returns jsonb language sql as $$ select jsonb_build_object('id', id, 'ref', art) $$;
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.f_mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','*','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_div(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','/','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_ceil(a jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','ceil','args', jsonb_build_array(a)) $$;

create or replace function pg_temp.rz_id(p_opt uuid, p_art text) returns uuid language sql as $$
  select rz.id from ressourcenzeile rz
    left join artikel a on a.id = rz.artikel_id
    left join sonderposition_typ st on st.id = rz.sonderposition_typ_id
   where rz.option_id = p_opt and ( a.bezeichnung = p_art or st.name = p_art )
   order by rz.reihenfolge, rz.id limit 1 $$;

create or replace function pg_temp.klon(p_src uuid, p_opt uuid, p_rr int, p_menge jsonb, p_artikel uuid default null, p_sonder uuid default null) returns uuid language plpgsql as $$
declare j jsonb; nid uuid := gen_random_uuid();
begin
  if p_src is null then raise exception 'Quellzeile fehlt (Option %, Reihenfolge %)', p_opt, p_rr; end if;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = p_src;
  j := j || jsonb_build_object('id', nid, 'option_id', p_opt, 'teilschritt_id', null, 'reihenfolge', p_rr,
        'menge_ausdruck', p_menge, 'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
        'verschnitt_prozent', null, 'mindestmenge', null, 'mengenoption_ausgenommen', false);
  if p_artikel is not null then j := j || jsonb_build_object('artikel_id', p_artikel, 'bezeichnung_override', null); end if;
  if p_sonder is not null then j := j || jsonb_build_object('sonderposition_typ_id', p_sonder, 'artikel_id', null, 'bezeichnung_override', null); end if;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
  return nid;
end $$;

do $$
declare
  ot uuid; as_nat uuid; ts_old uuid; af_old uuid; o_hand uuid; o_abt uuid; o_kw uuid;
  ts_new uuid := gen_random_uuid(); af_new uuid := gen_random_uuid(); o_mulde uuid := gen_random_uuid(); o_lw uuid := gen_random_uuid();
  t_gew uuid; a_mulde uuid := gen_random_uuid(); isen uuid; sp_chauf uuid; sp_lw uuid; tmpl jsonb; fuhren jsonb; legs jsonb;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_nat from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer';
  select ts.id into ts_old from teilschritt ts where ts.arbeitsschritt_id = as_nat order by ts.reihenfolge limit 1;
  select af.id into af_old from auswahlfeld af where af.teilschritt_id = ts_old limit 1;
  select o.id into o_hand from auswahloption o where o.auswahlfeld_id = af_old and o.name = 'von Hand';
  select o.id into o_abt from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
   where a.offertentyp_id = ot and o.name = 'Abtransport Mulde LKW';
  select o.id into o_kw from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
   where a.offertentyp_id = ot and o.name = 'Kies Lieferwagen';
  select id into t_gew from term where offertentyp_id = ot and name = 'Gewicht Natursteinmauer';
  select id into isen from lieferant where name = 'Isenschmid - Mulden, Transporte';
  select id into sp_chauf from sonderposition_typ where name = 'Lieferwagenchauffeur Magazin';
  select id into sp_lw from sonderposition_typ where name = 'Lieferwagentransport Magazin';
  if as_nat is null or o_hand is null or o_abt is null or o_kw is null or t_gew is null or isen is null or sp_chauf is null or sp_lw is null then
    raise exception 'Grundlage nicht wie erwartet gefunden - nichts geaendert.';
  end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_nat and name = 'Zwischentransport Natursteine') then raise exception 'Zwischentransport gibt es schon'; end if;

  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values (a_mulde, isen, 'logistik', 'KNECHT_ZWISCHENTRANSPORT_01', 'ZWT_MULDE_10T', 'Zwischentransport Mulde Natursteine (10 t je Fuhre)', 'Fuhre', 370, 'CHF', 1, 8.1, false, false, false, true, false);

  select to_jsonb(ts) into tmpl from teilschritt ts where ts.id = ts_old;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_new, 'name', 'Zwischentransport Natursteine', 'reihenfolge', 2, 'beschreibung', null));
  select to_jsonb(af) into tmpl from auswahlfeld af where af.id = af_old;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_new, 'teilschritt_id', ts_new, 'name', 'Zwischentransport Natursteine'));
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_hand;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', o_mulde, 'auswahlfeld_id', af_new, 'name', 'Mulde LKW', 'reihenfolge', 1,
      'beschreibung', 'Natursteine ab Lager Knecht mit Muldenfahrzeug zur Baustelle transportieren.', 'mengenoption', false, 'mehrfachauswahl', false, 'tabellenverweis', null));
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', o_lw, 'auswahlfeld_id', af_new, 'name', 'Lieferwagen ab Lager', 'reihenfolge', 2,
      'beschreibung', 'Natursteine ab Lager Knecht mit dem Lieferwagen zur Baustelle transportieren.', 'mengenoption', false, 'mehrfachauswahl', false, 'tabellenverweis', null));

  -- Mulde: Fuhren = aufgerundet (Gewicht / 10 t)
  fuhren := pg_temp.f_ceil(pg_temp.f_div(pg_temp.f_ref('term', t_gew), pg_temp.f_lit(10)));
  perform pg_temp.klon(pg_temp.rz_id(o_abt, 'Muldentransporte 4-9m3'), o_mulde, 1, fuhren, a_mulde);
  perform pg_temp.klon(pg_temp.rz_id(o_hand, 'Polier / Vorarbeiter Wassergärten Spezialpreis anstelle 132.00'), o_mulde, 2, pg_temp.f_mul(fuhren, pg_temp.f_lit(1.5)));
  perform pg_temp.klon(pg_temp.rz_id(o_hand, 'Gartenarbeiter'), o_mulde, 3, pg_temp.f_mul(fuhren, pg_temp.f_lit(1.5)));

  -- Lieferwagen: 1 Fahrt je Tonne, jede Fahrt = Hin- und Rückstrecke (2 Strecken)
  legs := pg_temp.f_mul(pg_temp.f_ref('term', t_gew), pg_temp.f_lit(2));
  perform pg_temp.klon(pg_temp.rz_id(o_kw, 'Lieferwagenchauffeur Pool Kieswerk/Betonwerk'), o_lw, 1, legs, null, sp_chauf);
  perform pg_temp.klon(pg_temp.rz_id(o_kw, 'Lieferwagentransport Kieswerk/Betonwerk'), o_lw, 2, legs, null, sp_lw);
  raise notice 'Zwischentransport angelegt.';
end $$;
