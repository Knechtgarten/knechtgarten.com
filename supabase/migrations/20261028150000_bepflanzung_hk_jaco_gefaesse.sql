-- Offertenvorlage Bepflanzung (2026-10-28): restliche Gefaesse im Stil der U-Form (Vorlage: Option U60-black):
--  * Atelier Vierkant HK-Form: HK 40-grau vervollstaendigt, dazu HK 40-black, HK 60/75/90 in grau + black
--    (HKL40 und HK130 fehlen: kein Artikel im Artikelstamm).
--  * Neuer Teilschritt "Jaco Gefaesse" (Arbeitsschritt "Gefaesse befuellt"): Austin 45/55/65, Elena 50/70/90, Naimo 80/94/110
--    je in Espresso, Quarz, Sand, Cappuccino (36 Optionen), Artikel aus dem Artikelstamm (Jacko - Beck AG), Foto als Hinweisbild.
-- Mengen aus der Tabelle "Berechnungsgrundlagen" (Blaehton 20 %, Trogerde 80 %, Trenngewebe, Zeitaufwand), gerundet wie bei der U-Form:
-- Trogerde Saecke (30 L) auf 0.5 abgerundet (min. 0.5), Blaehton Saecke (50 L) auf 0.05, Trenngewebe m2 auf 0.1, Zeit = Zeitaufwand fuer Polier UND Gartenarbeiter.
-- Topf-Befestigungspunkte (3 Stk.) ab 125 L Gefaessinhalt wie ab U70.
create or replace function pg_temp.f_artikel(p_nr text) returns uuid language plpgsql as $$
declare i uuid;
begin
  select id into i from artikel where artikelnummer_knecht = p_nr;
  if i is null then raise exception 'Artikel % nicht gefunden', p_nr; end if;
  return i;
end $$;

create or replace function pg_temp.neue_zeile(p_src_opt uuid, p_muster text, p_opt uuid, p_rr int, p_menge numeric, p_einheit text, p_artikel uuid default null) returns void language plpgsql as $$
declare j jsonb;
begin
  select to_jsonb(rz) into j from ressourcenzeile rz join artikel a on a.id = rz.artikel_id where rz.option_id = p_src_opt and a.bezeichnung like p_muster limit 1;
  if j is null then raise exception 'Quellzeile "%" fehlt', p_muster; end if;
  j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', p_opt, 'teilschritt_id', null, 'reihenfolge', p_rr,
        'menge_ausdruck', jsonb_build_object('lit', p_menge, '_einheit', p_einheit));
  if p_artikel is not null then j := j || jsonb_build_object('artikel_id', p_artikel); end if;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
end $$;

-- p_gefaess = Artikel des Gefaesses; p_neu = Option neu anlegen (false = bestehende Option vervollstaendigen)
create or replace function pg_temp.baue_option(p_af uuid, p_name text, p_rr int, p_gefaess uuid, p_std numeric, p_gew numeric, p_erde numeric, p_bl numeric, p_bef int, p_neu boolean default true) returns void language plpgsql as $$
declare
  src constant uuid := '03a52bf6-d214-4ea4-98d4-64ba42432620'; -- U60-black
  src_bef uuid; opt uuid; j jsonb; bild text; rr int := 0;
begin
  select id into src_bef from auswahloption where name = 'U70-black' and auswahlfeld_id = '2c9b7d8f-483a-4095-9582-b0cc4986ae4f';
  if p_neu then
    select foto_url into bild from artikel where id = p_gefaess;
    select to_jsonb(o) into j from auswahloption o where o.id = src;
    opt := gen_random_uuid();
    j := j || jsonb_build_object('id', opt, 'auswahlfeld_id', p_af, 'name', p_name, 'reihenfolge', p_rr, 'hinweisbild_url', bild,
          'beschreibung', 'Gefäss liefern und montieren. Inkl. Ablaufgitter, Blähton, spez. Trenngewebe');
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j);
    perform pg_temp.neue_zeile(src, 'Polier / Vorarbeiter', opt, 1, p_std, 'Std.');
    perform pg_temp.neue_zeile(src, 'Gartenarbeiter', opt, 2, p_std, 'Std.');
    perform pg_temp.neue_zeile(src, 'Gefäss Atelier Vierkant U60 Schwarz', opt, 3, 1, 'Stk.', p_gefaess);
    rr := 3;
  else
    select id into opt from auswahloption where auswahlfeld_id = p_af and name = p_name;
    if opt is null then raise exception 'Option % nicht gefunden', p_name; end if;
    select coalesce(max(reihenfolge), 0) into rr from ressourcenzeile where option_id = opt;
  end if;
  perform pg_temp.neue_zeile(src, 'Ablaufgitter runde Gefässe', opt, rr + 1, 1, 'Stk.');
  rr := rr + 1;
  if p_bef > 0 then
    perform pg_temp.neue_zeile(src_bef, 'Topf-Befestigungspunkt%', opt, rr + 1, p_bef, 'Stk.');
    rr := rr + 1;
  end if;
  perform pg_temp.neue_zeile(src, 'Sytec Geofiltergewebe%', opt, rr + 1, p_gew, 'm²');
  perform pg_temp.neue_zeile(src, 'Ökohum Dach und Trogerde intensiv 30L', opt, rr + 2, p_erde, 'Sack');
  perform pg_temp.neue_zeile(src, 'Ökohum Blähton 50l%', opt, rr + 3, p_bl, 'Sack');
end $$;

do $$
declare
  as_id constant uuid := 'd9604cdf-1fa0-4201-a057-128a4dd37b6e';
  af_hk constant uuid := '7d5b37ee-f0e9-4ced-9fc3-b8c4d8e5d94e';
  ts_j uuid := gen_random_uuid(); af_j uuid := gen_random_uuid();
  rec record; farbe record; r int; n_ok int;
begin
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name = 'Jaco Gefässe') then raise exception 'Jaco Gefässe existiert schon'; end if;

  -- 1) HK-Form
  perform pg_temp.baue_option(af_hk, 'HK 40-grau', 1, pg_temp.f_artikel('ATELIE_HK40G'), 0.2, 0.2, 0.5, 0.1, 0, false);
  r := 1;
  for rec in select * from (values ('HK 40','ATELIE_HK40',0.2,0.2,0.5,0.1,0),('HK 60','ATELIE_HK60',0.4,0.4,3,0.5,3),('HK 75','ATELIE_HK75',0.5,0.6,5,0.8,3),('HK 90','ATELIE_HK90',0.6,0.9,7.5,1.15,3))
        as v(lbl, nr, std, gew, erde, bl, bef) loop
    for farbe in select * from (values ('grau','G'),('black','Z')) as f(name, suf) loop
      if rec.lbl = 'HK 40' and farbe.name = 'grau' then continue; end if;
      r := r + 1;
      perform pg_temp.baue_option(af_hk, rec.lbl || '-' || farbe.name, r, pg_temp.f_artikel(rec.nr || farbe.suf), rec.std, rec.gew, rec.erde, rec.bl, rec.bef);
    end loop;
  end loop;

  -- 2) Jaco Gefaesse: neuer Teilschritt mit Auswahlfeld
  insert into teilschritt (id, arbeitsschritt_id, name, reihenfolge, ausgeblendet, ist_belag)
    values (ts_j, as_id, 'Jaco Gefässe', (select coalesce(max(reihenfolge), 0) + 1 from teilschritt where arbeitsschritt_id = as_id), false, false);
  insert into auswahlfeld (id, teilschritt_id, name, reihenfolge) values (af_j, ts_j, 'Jaco Gefässe', 1);
  r := 0;
  for rec in select * from (values
      ('Austin 45','7045',0.2,0.2,1.5,0.25,0),('Austin 55','7055',0.2,0.3,2.5,0.4,0),('Austin 65','7065',0.2,0.4,4,0.65,3),
      ('Elena 50','3150',0.2,0.3,1,0.15,0),('Elena 70','3170',0.2,0.5,2,0.3,0),('Elena 90','3190',0.2,0.8,3,0.5,0),
      ('Naimo 80','1180',0.2,0.6,6.5,1,3),('Naimo 94','1194',0.2,0.9,9.5,1.45,3),('Naimo 110','1111',0.2,1.2,16,2.4,3))
      as v(lbl, num, std, gew, erde, bl, bef) loop
    for farbe in select * from (values ('Espresso','TES'),('Quarz','TQU'),('Sand','TSA'),('Cappuccino','TCA')) as f(name, code) loop
      r := r + 1;
      perform pg_temp.baue_option(af_j, rec.lbl || ' ' || farbe.name, r, pg_temp.f_artikel('JACO_' || farbe.code || '20.' || rec.num), rec.std, rec.gew, rec.erde, rec.bl, rec.bef);
    end loop;
  end loop;

  select count(*) into n_ok from auswahloption where auswahlfeld_id = af_j;
  if n_ok <> 36 then raise exception 'Erwartet 36 Jaco-Optionen, erzeugt %', n_ok; end if;
  select count(*) into n_ok from auswahloption where auswahlfeld_id = af_hk;
  if n_ok <> 8 then raise exception 'Erwartet 8 HK-Optionen, gefunden %', n_ok; end if;
end $$;
