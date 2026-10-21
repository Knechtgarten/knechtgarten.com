-- ============================================================================
-- Mauern / Blendmauer, Ueberarbeitung nach Abgleich mit dem Excel "Verblendmauer":
--  * Tabelle "Blendmauer" bekommt das Fundament: Fundamentbreite (0.65 m) und
--    Fundamentdicke (50 cm) als Eingabe; berechnet werden Fundamentflaeche
--    ((Laenge + 0.3 m) x Breite), Fundamentbeton und Aushub (Dicke + 5 cm
--    Sauberkeitsschicht, fest).
--  * Teilschritt "Betonmauer (Fundament und Wand)": Optionen
--      - "Betonmauer gepumpt"       (Betonpumpe + Beton-Transport)
--      - "Betonmauer mit Lieferwagen" (Lieferwagen 0.5 m3 pro Fahrt, hin und zurueck)
--    beide enthalten Fundament UND Wand.
--  * Teilschritt "Verputzen": "Verputzen einseitig" / "zweiseitig" (Arbeitszeit;
--    Perricret-Material folgt, sobald es den Artikel gibt).
--  * Der Aushub der Blendmauer fliesst in den bestehenden Aushub (Baumaschinen,
--    Abtransport) ein - die Kies-Fundation bleibt davon unberuehrt.
-- ============================================================================
create or replace function pg_temp.f_ref(art text, id uuid) returns jsonb language sql as $$ select jsonb_build_object('id', id, 'ref', art) $$;
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.f_mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','*','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_add(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','+','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_div(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','/','args', jsonb_build_array(a, b)) $$;

do $$
declare
  ot uuid; pool_ot uuid; ef uuid;
  sp_l uuid; sp_h uuid; sp_d uuid; sp_fl uuid; sp_vol uuid;
  sp_fb uuid := gen_random_uuid(); sp_fd uuid := gen_random_uuid(); sp_ffl uuid := gen_random_uuid();
  sp_fbeton uuid := gen_random_uuid(); sp_ah uuid := gen_random_uuid();
  t_fl uuid; t_wand uuid; t_ffl uuid := gen_random_uuid(); t_fb uuid := gen_random_uuid(); t_ah uuid := gen_random_uuid();
  t_beton uuid := gen_random_uuid(); t_ah_ges uuid := gen_random_uuid();
  t_aushub_alt uuid; t_auflock uuid;
  as_bm uuid; ts_bm uuid; af_bm uuid; opt_pump uuid; opt_lw uuid;
  ts_v uuid := gen_random_uuid(); af_v uuid := gen_random_uuid(); opt_v1 uuid := gen_random_uuid(); opt_v2 uuid := gen_random_uuid();
  j jsonb; rec record; rr int; n int;
  fl jsonb; beton jsonb; ffl jsonb; fbeton jsonb;
  m_fl jsonb; m_beton jsonb; m_ffl jsonb;
  personal jsonb;
  tmpl_term jsonb; tmpl_spalte jsonb;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into pool_ot from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  select e.id into ef from eingabefeld e where e.offertentyp_id = ot and e.name = 'Blendmauer' and e.ist_tabelle;
  if ef is null then raise exception 'Tabelle Blendmauer nicht gefunden'; end if;
  select s.id into sp_l from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Länge';
  select s.id into sp_h from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Höhe';
  select s.id into sp_d from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Dicke';
  select s.id into sp_fl from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Fläche';
  select s.id into sp_vol from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name in ('Volumen','Volumen Wand');
  select t.id into t_fl from term t where t.offertentyp_id = ot and t.name = 'Fläche Blendmauer';
  select t.id into t_wand from term t where t.offertentyp_id = ot and t.name in ('Volumen Blendmauer','Wandbeton Blendmauer');
  select t.id into t_aushub_alt from term t where t.offertentyp_id = ot and t.name = 'Volumen Aushub locker';
  select t.id into t_auflock from term t where t.offertentyp_id = ot and t.name = 'Auflockerungsfaktor';
  select a.id into as_bm from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Blendmauer';
  select ts.id into ts_bm from teilschritt ts where ts.arbeitsschritt_id = as_bm limit 1;
  select af.id into af_bm from auswahlfeld af where af.teilschritt_id = ts_bm limit 1;
  select o.id into opt_pump from auswahloption o where o.auswahlfeld_id = af_bm and o.name = 'Betonwand';
  if sp_l is null or sp_h is null or sp_d is null or sp_fl is null or sp_vol is null or t_fl is null or t_wand is null
     or t_aushub_alt is null or t_auflock is null or as_bm is null or ts_bm is null or af_bm is null or opt_pump is null then
    raise exception 'Blendmauer-Grundlage nicht wie erwartet gefunden - nichts geaendert.';
  end if;

  -- 1) Tabelle: Spalten umbenennen/ordnen, neue Spalten
  update eingabefeld_tabelle_spalte set reihenfolge = 1 where id = sp_l;
  update eingabefeld_tabelle_spalte set reihenfolge = 2 where id = sp_h;
  update eingabefeld_tabelle_spalte set reihenfolge = 3 where id = sp_d;
  update eingabefeld_tabelle_spalte set reihenfolge = 6 where id = sp_fl;
  update eingabefeld_tabelle_spalte set reihenfolge = 7, name = 'Volumen Wand' where id = sp_vol;
  select to_jsonb(s) into tmpl_spalte from eingabefeld_tabelle_spalte s where s.id = sp_l;

  ffl := pg_temp.f_mul(
           pg_temp.f_add(pg_temp.f_ref('spalte', sp_l),
             pg_temp.f_mul(pg_temp.f_lit(0.3), pg_temp.f_div(pg_temp.f_ref('spalte', sp_l), pg_temp.f_add(pg_temp.f_ref('spalte', sp_l), pg_temp.f_lit(0.000000001))))),
           pg_temp.f_ref('spalte', sp_fb));
  fbeton := pg_temp.f_mul(pg_temp.f_ref('spalte', sp_ffl), pg_temp.f_mul(pg_temp.f_ref('spalte', sp_fd), pg_temp.f_lit(0.01)));

  for rec in
    select * from (values
      (sp_fb,    'Fundamentbreite', 'm',  4, false, null::jsonb, 0.65::numeric),
      (sp_fd,    'Fundamentdicke',  'cm', 5, false, null::jsonb, 50::numeric),
      (sp_ffl,   'Fundamentfläche', 'm²', 8, true,  ffl, null::numeric),
      (sp_fbeton,'Fundamentbeton',  'm³', 9, true,  fbeton, null::numeric),
      (sp_ah,    'Aushub',          'm³', 10, true,
         pg_temp.f_mul(pg_temp.f_ref('spalte', sp_ffl), pg_temp.f_mul(pg_temp.f_add(pg_temp.f_ref('spalte', sp_fd), pg_temp.f_lit(5)), pg_temp.f_lit(0.01))), null::numeric)
    ) as v(id, name, einheit, reihenfolge, berechnet, ausdruck, vorschlag)
  loop
    j := tmpl_spalte || jsonb_build_object('id', rec.id, 'eingabefeld_id', ef, 'name', rec.name, 'einheit', rec.einheit,
          'reihenfolge', rec.reihenfolge, 'ist_berechnung', rec.berechnet, 'ausdruck', rec.ausdruck, 'vorschlagswert', rec.vorschlag);
    insert into eingabefeld_tabelle_spalte select * from jsonb_populate_record(null::eingabefeld_tabelle_spalte, j);
  end loop;

  -- 2) Formeln (Summen ueber alle Zeilen)
  select to_jsonb(t) into tmpl_term from term t where t.id = t_fl;
  update term set name = 'Wandbeton Blendmauer' where id = t_wand;
  for rec in
    select * from (values
      (t_ffl, 'Fundamentfläche Blendmauer', 'm²', pg_temp.f_ref('spalte', sp_ffl)),
      (t_fb,  'Fundamentbeton Blendmauer',  'm³', pg_temp.f_ref('spalte', sp_fbeton)),
      (t_ah,  'Aushub Blendmauer (fest)',   'm³', pg_temp.f_ref('spalte', sp_ah)),
      (t_beton,'Beton Blendmauer total (Wand + Fundament)', 'm³', pg_temp.f_add(pg_temp.f_ref('term', t_wand), pg_temp.f_ref('term', t_fb))),
      (t_ah_ges,'Volumen Aushub locker inkl. Blendmauer', 'm³',
         pg_temp.f_add(pg_temp.f_ref('term', t_aushub_alt), pg_temp.f_mul(pg_temp.f_ref('term', t_ah), pg_temp.f_ref('term', t_auflock))))
    ) as v(id, name, einheit, ausdruck)
  loop
    j := tmpl_term || jsonb_build_object('id', rec.id, 'name', rec.name, 'einheit', rec.einheit, 'ausdruck', rec.ausdruck,
          'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot));
    insert into term select * from jsonb_populate_record(null::term, j);
  end loop;

  -- 3) Aushub-Zeilen (nur Arbeitsschritt "Aushub") auf "Volumen Aushub locker inkl. Blendmauer" umhaengen
  update ressourcenzeile rz
     set menge_ausdruck = replace(rz.menge_ausdruck::text, t_aushub_alt::text, t_ah_ges::text)::jsonb
    from auswahloption o, auswahlfeld af, teilschritt ts, arbeitsschritt a
   where rz.option_id = o.id and af.id = o.auswahlfeld_id and ts.id = af.teilschritt_id and a.id = ts.arbeitsschritt_id
     and a.offertentyp_id = ot and a.name = 'Aushub' and rz.menge_ausdruck::text like '%' || t_aushub_alt::text || '%';
  get diagnostics n = row_count;
  raise notice 'Aushub-Zeilen umgehaengt: %', n;

  -- 4) Betonmauer-Optionen: bestehende Zeilen der Option "Betonwand" als Vorlage merken, dann neu aufbauen
  create temp table _bm_alt on commit drop as select rz.* from ressourcenzeile rz where rz.option_id = opt_pump;
  delete from ressourcenzeile where option_id = opt_pump;
  update teilschritt set name = 'Betonmauer (Fundament und Wand)' where id = ts_bm;
  update auswahlfeld set name = 'Betonmauer (Fundament und Wand)' where id = af_bm;
  update auswahloption set name = 'Betonmauer gepumpt', beschreibung = 'Fundament und Betonmauer mit gepumptem Beton erstellen.', reihenfolge = 1 where id = opt_pump;

  select to_jsonb(o) into j from auswahloption o where o.id = opt_pump;
  opt_lw := gen_random_uuid();
  j := j || jsonb_build_object('id', opt_lw, 'name', 'Betonmauer mit Lieferwagen', 'reihenfolge', 2,
        'beschreibung', 'Fundament und Betonmauer mit Beton aus dem Betonwerk (Lieferwagen) erstellen.');
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j);

  m_fl    := pg_temp.f_ref('term', t_fl);
  m_beton := pg_temp.f_ref('term', t_beton);
  m_ffl   := pg_temp.f_ref('term', t_ffl);
  -- Arbeitszeit: Wand 1.1 Std/m2 (Pool-Wert) + Fundament 3 Std/m3 Beton (Pool Betonkragen)
  personal := pg_temp.f_add(pg_temp.f_mul(m_fl, pg_temp.f_lit(1.1)), pg_temp.f_mul(pg_temp.f_ref('term', t_fb), pg_temp.f_lit(3)));

  -- 4a) gepumpt
  rr := 0;
  for rec in select * from _bm_alt order by reihenfolge loop
    rr := rr + 1;
    j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_pump, 'reihenfolge', rr);
    if rr in (1,2) then j := j || jsonb_build_object('menge_ausdruck', personal);          -- Polier, Gartenarbeiter
    elsif rr in (3,4,5) then j := j || jsonb_build_object('menge_ausdruck', m_beton);        -- Pumpe, Transport, SVB
    elsif rr = 6 then j := j || jsonb_build_object('menge_ausdruck', pg_temp.f_mul(m_fl, pg_temp.f_lit(8)));  -- Armierungsstahl Wand
    end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
  end loop;
  -- Armierungsnetz Fundament (aus Pool Bodenplatte)
  select to_jsonb(rz) into j
    from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld af on af.id = o.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
   where a.offertentyp_id = pool_ot and o.name = 'Bodenplatte armiert' and rz.reihenfolge = 11 limit 1;
  if j is null then raise exception 'Pool-Zeile Armierungsnetz nicht gefunden'; end if;
  rr := rr + 1;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    j || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_pump, 'teilschritt_id', null, 'reihenfolge', rr, 'menge_ausdruck', m_ffl,
      'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null));

  -- 4b) mit Lieferwagen: Personal, SVB, Armierung, Netz, Geraete + Lieferwagenfahrten (0.5 m3 pro Fahrt, hin und zurueck)
  rr := 0;
  for rec in select * from _bm_alt where kategorie in ('personal') or reihenfolge in (5, 6, 9) order by reihenfolge loop
    rr := rr + 1;
    j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_lw, 'reihenfolge', rr);
    if rec.kategorie = 'personal' then j := j || jsonb_build_object('menge_ausdruck', personal);
    elsif rec.reihenfolge = 5 then j := j || jsonb_build_object('menge_ausdruck', m_beton);
    elsif rec.reihenfolge = 6 then j := j || jsonb_build_object('menge_ausdruck', pg_temp.f_mul(m_fl, pg_temp.f_lit(8)));
    end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
  end loop;
  rr := rr + 1;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    (select to_jsonb(rz) from ressourcenzeile rz where rz.option_id = opt_pump and rz.reihenfolge = 10)
    || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_lw, 'reihenfolge', rr));
  -- Lieferwagenchauffeur + Lieferwagentransport (aus "Fundation Kieseinbau Lieferwagen")
  for rec in
    select rz.* from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld af on af.id = o.auswahlfeld_id
      join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
     where a.offertentyp_id = ot and ts.name like 'Fundation Kieseinbau Lieferwagen%' and rz.sonderposition_typ_id is not null
     order by rz.reihenfolge
  loop
    rr := rr + 1;
    j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_lw, 'teilschritt_id', null, 'reihenfolge', rr,
          'menge_ausdruck', pg_temp.f_mul(m_beton, pg_temp.f_lit(4)));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
  end loop;

  -- 5) Teilschritt "Verputzen": einseitig / zweiseitig (Arbeitszeit 0.25 Std/m2 und Seite)
  select to_jsonb(ts) into j from teilschritt ts where ts.id = ts_bm;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j || jsonb_build_object('id', ts_v, 'name', 'Verputzen', 'reihenfolge', 2, 'beschreibung', null));
  select to_jsonb(af) into j from auswahlfeld af where af.id = af_bm;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j || jsonb_build_object('id', af_v, 'teilschritt_id', ts_v, 'name', 'Verputzen'));
  for rec in select * from (values (opt_v1, 'Verputzen einseitig', 1, 1, 'Betonmauer einseitig verputzen (Perricret).'),
                                   (opt_v2, 'Verputzen zweiseitig', 2, 2, 'Betonmauer beidseitig verputzen (Perricret).')) as v(id, name, reihenfolge, seiten, text)
  loop
    select to_jsonb(o) into j from auswahloption o where o.id = opt_pump;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
      j || jsonb_build_object('id', rec.id, 'auswahlfeld_id', af_v, 'name', rec.name, 'reihenfolge', rec.reihenfolge, 'beschreibung', rec.text));
    rr := 0;
    for n in 1..2 loop
      rr := rr + 1;
      select to_jsonb(r) into j from _bm_alt r where r.kategorie = 'personal' order by r.reihenfolge offset (n - 1) limit 1;
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
        j || jsonb_build_object('id', gen_random_uuid(), 'option_id', rec.id, 'reihenfolge', rr,
          'menge_ausdruck', pg_temp.f_mul(m_fl, pg_temp.f_lit(0.25 * rec.seiten))));
    end loop;
  end loop;

  raise notice 'Blendmauer v2 angelegt.';
end $$;
