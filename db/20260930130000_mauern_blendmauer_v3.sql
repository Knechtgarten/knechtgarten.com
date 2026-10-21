-- ============================================================================
-- Mauern / Blendmauer v3:
--  * Wanddicke faellt weg (Coffra-Stein hat ein festes Mass). Wandbeton =
--    Flaeche x 0.2 m3/m2 (Wert aus dem Pool "Waende betonieren", als Konstante
--    "Fuellbeton pro m2 Wand" in der Formel-Bibliothek aenderbar).
--  * Wand wie im Pool: Ueberzug 350 kg/m3 (Fuellbeton), Permafix, Pistolenreiniger,
--    Armierung; dazu der COFFRA Schalungsstein (Flaeche + 10 % Verschnitt).
--    Fundamentbeton bleibt SVB.
--  * Verputzen wie im Pool "Waende verputzen": 0.65 Std/m2, PCI Pericret (Flaeche / 7),
--    Hilfsmaterial pauschal; einseitig = x1, zweiseitig = x2.
--  * Rechenspalten der Blendmauer-Tabelle werden nicht angezeigt (rechnen im Hintergrund).
--  * Tabelle "Fundation" (Natursteinmauer): kuerzere Spaltentitel Laenge/Breite/Tiefe/Volumen.
-- ============================================================================
create or replace function pg_temp.f_ref(art text, id uuid) returns jsonb language sql as $$ select jsonb_build_object('id', id, 'ref', art) $$;
create or replace function pg_temp.f_lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.f_mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','*','args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.f_div(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op','/','args', jsonb_build_array(a, b)) $$;

do $$
declare
  ot uuid; pool_ot uuid; ef uuid; ef_fund uuid;
  sp_d uuid; sp_fl uuid; sp_vol uuid;
  t_fl uuid; t_wand uuid; t_fb uuid; t_fuell uuid := gen_random_uuid(); tmpl_term jsonb;
  opt_p uuid; opt_l uuid; opt_v1 uuid; opt_v2 uuid;
  coffra_id uuid; j jsonb; rec record; oo record; rr int; n int;
  m_fl jsonb; m_wand jsonb; m_fb jsonb; svb jsonb;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into pool_ot from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  select e.id into ef from eingabefeld e where e.offertentyp_id = ot and e.name = 'Blendmauer' and e.ist_tabelle;
  select e.id into ef_fund from eingabefeld e where e.offertentyp_id = ot and e.name = 'Fundation' and e.ist_tabelle;
  select s.id into sp_d from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Dicke';
  select s.id into sp_fl from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Fläche';
  select s.id into sp_vol from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef and s.name = 'Volumen Wand';
  select t.id into t_fl from term t where t.offertentyp_id = ot and t.name = 'Fläche Blendmauer';
  select t.id into t_wand from term t where t.offertentyp_id = ot and t.name = 'Wandbeton Blendmauer';
  select t.id into t_fb from term t where t.offertentyp_id = ot and t.name = 'Fundamentbeton Blendmauer';
  select o.id into opt_p from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and o.name = 'Betonmauer gepumpt';
  select o.id into opt_l from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and o.name = 'Betonmauer mit Lieferwagen';
  select o.id into opt_v1 from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and o.name = 'Verputzen einseitig';
  select o.id into opt_v2 from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot and o.name = 'Verputzen zweiseitig';
  select id into coffra_id from artikel where bezeichnung = 'COFFRA Schalungsstein' limit 1;
  if ef is null or sp_d is null or sp_fl is null or sp_vol is null or t_fl is null or t_wand is null or t_fb is null
     or opt_p is null or opt_l is null or opt_v1 is null or opt_v2 is null or coffra_id is null then
    raise exception 'Blendmauer-Grundlage nicht wie erwartet gefunden - nichts geaendert.';
  end if;

  -- 1) Konstante "Fuellbeton pro m2 Wand" (Pool-Wert 0.2) und Wanddicke entfernen
  select to_jsonb(t) into tmpl_term from term t where t.id = t_fl;
  tmpl_term := tmpl_term || jsonb_build_object('id', t_fuell, 'name', 'Füllbeton pro m² Wand', 'typ', 'konstante', 'wert', 0.2, 'einheit', 'm³/m²',
                 'ausdruck', null, 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot));
  insert into term select * from jsonb_populate_record(null::term, tmpl_term);
  update eingabefeld_tabelle_spalte
     set ausdruck = pg_temp.f_mul(pg_temp.f_ref('spalte', sp_fl), pg_temp.f_ref('term', t_fuell))
   where id = sp_vol;
  delete from eingabefeld_tabelle_spalte where id = sp_d;
  -- Reihenfolge neu: Laenge, Hoehe, Fundamentbreite, Fundamentdicke, Flaeche, Volumen Wand, Fundamentflaeche, Fundamentbeton, Aushub
  update eingabefeld_tabelle_spalte s set reihenfolge = v.r
    from (values ('Länge',1),('Höhe',2),('Fundamentbreite',3),('Fundamentdicke',4),('Fläche',5),('Volumen Wand',6),('Fundamentfläche',7),('Fundamentbeton',8),('Aushub',9)) as v(n, r)
   where s.eingabefeld_id = ef and s.name = v.n;
  -- Rechenspalten im Konfigurator ausblenden
  update eingabefeld_tabelle_spalte set ausgeblendet = true where eingabefeld_id = ef and ist_berechnung;

  -- 2) Wand wie im Pool: Betonmauer gepumpt / mit Lieferwagen
  m_fl := pg_temp.f_ref('term', t_fl);
  m_wand := pg_temp.f_ref('term', t_wand);
  m_fb := pg_temp.f_ref('term', t_fb);
  for oo in select unnest(array[opt_p, opt_l]) as id loop
    -- SVB Beton: nur noch Fundament
    update ressourcenzeile set menge_ausdruck = m_fb
     where option_id = oo.id and artikel_id = (select id from artikel where bezeichnung = 'SVB Beton' limit 1);
    select coalesce(max(reihenfolge), 0) into rr from ressourcenzeile where option_id = oo.id;
    -- Ueberzug (Fuellbeton Wand), Permafix, Pistolenreiniger aus dem Pool
    for rec in
      select * from (values (7, m_wand), (3, pg_temp.f_div(m_fl, pg_temp.f_lit(4))), (4, pg_temp.f_div(m_fl, pg_temp.f_lit(4.5)))) as v(pool_r, formel)
    loop
      select to_jsonb(rz) into j
        from ressourcenzeile rz join auswahloption po on po.id = rz.option_id join auswahlfeld af on af.id = po.auswahlfeld_id
        join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
       where a.offertentyp_id = pool_ot and po.name = 'Wände betonieren' and rz.reihenfolge = rec.pool_r order by rz.id limit 1;
      if j is null then raise exception 'Pool-Zeile Waende betonieren / % nicht gefunden', rec.pool_r; end if;
      rr := rr + 1;
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
        j || jsonb_build_object('id', gen_random_uuid(), 'option_id', oo.id, 'teilschritt_id', null, 'reihenfolge', rr, 'menge_ausdruck', rec.formel,
              'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null));
    end loop;
    -- COFFRA Schalungsstein: Wandflaeche + 10 % Verschnitt/Eckausbildung
    select to_jsonb(rz) into j from ressourcenzeile rz
     where rz.option_id = oo.id and rz.artikel_id = (select id from artikel where bezeichnung = 'SVB Beton' limit 1) limit 1;
    rr := rr + 1;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      j || jsonb_build_object('id', gen_random_uuid(), 'artikel_id', coffra_id, 'reihenfolge', rr, 'menge_ausdruck', m_fl, 'verschnitt_prozent', 10));
  end loop;

  -- 3) Verputzen wie im Pool "Waende verputzen" (0.65 Std/m2, Pericret Flaeche/7 min 1, Hilfsmaterial pauschal)
  for oo in select * from (values (opt_v1, 1), (opt_v2, 2)) as v(id, seiten) loop
    update ressourcenzeile set menge_ausdruck = pg_temp.f_mul(m_fl, pg_temp.f_lit(0.65 * oo.seiten)) where option_id = oo.id and kategorie = 'personal';
    select coalesce(max(reihenfolge), 0) into rr from ressourcenzeile where option_id = oo.id;
    for rec in
      select * from (values (3, pg_temp.f_div(pg_temp.f_mul(m_fl, pg_temp.f_lit(oo.seiten)), pg_temp.f_lit(7))), (4, null::jsonb)) as v(pool_r, formel)
    loop
      select to_jsonb(rz) into j
        from ressourcenzeile rz join auswahloption po on po.id = rz.option_id join auswahlfeld af on af.id = po.auswahlfeld_id
        join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
       where a.offertentyp_id = pool_ot and po.name = 'Wände verputzen' and rz.reihenfolge = rec.pool_r order by rz.id limit 1;
      if j is null then raise exception 'Pool-Zeile Waende verputzen / % nicht gefunden', rec.pool_r; end if;
      rr := rr + 1;
      j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', oo.id, 'teilschritt_id', null, 'reihenfolge', rr,
            'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null);
      if rec.formel is not null then j := j || jsonb_build_object('menge_ausdruck', rec.formel); end if;
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
    end loop;
  end loop;

  -- 4) Tabelle "Fundation" (Natursteinmauer): kurze Titel
  if ef_fund is not null then
    update eingabefeld_tabelle_spalte set name = 'Länge'  where eingabefeld_id = ef_fund and name = 'Fundamentlänge';
    update eingabefeld_tabelle_spalte set name = 'Breite' where eingabefeld_id = ef_fund and name = 'Fundamentbreite';
    update eingabefeld_tabelle_spalte set name = 'Tiefe'  where eingabefeld_id = ef_fund and name = 'Fundamenttiefe';
    update eingabefeld_tabelle_spalte set name = 'Volumen' where eingabefeld_id = ef_fund and name = 'Fundamentvolumen';
  end if;
  raise notice 'Blendmauer v3 fertig.';
end $$;
