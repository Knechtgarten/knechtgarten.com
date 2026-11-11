-- ============================================================================
-- Bepflanzung im Flächen-System wie «Beläge, Hartflächen»
-- Neue Vorlage «Bepflanzung» als KOPIE der bisherigen (id cc7690c3-…), die alte heisst
-- danach «Bepflanzung (alt)», ist ausgeblendet und rechnet ihre Offerten unverändert weiter.
--
-- Unterschiede der Kopie:
--  * Tabelle «Pflanzflächen» (Spalte Fläche m², Flächenformel möglich) statt Pflanzfläche 1–4
--  * Tabelle «Hecken» (Spalte Länge m) statt Hecke 1–4
--  * Optionen, die mit «Pflanzfläche Total» / «Hecke Total» rechneten, bekommen einen
--    Tabellenverweis; die Formel rechnet pro m² bzw. pro m (Total → 1), die Menge kommt
--    aus den angehakten Zeilen. Gruppen: pflanzung / mulch (Pflanzflächen), hecke (Hecken).
--  * Mulchen: Mehrfachauswahl (pro Fläche ein anderer Mulch möglich).
-- Alles andere 1:1. Läuft in EINER Transaktion: bei einem Fehler wird nichts angelegt.
-- ============================================================================
do $$
declare
  alt_ot  constant uuid := 'cc7690c3-8427-4810-9a7a-136ae7e9d67d';
  neu_ot  uuid := gen_random_uuid();
  a_t_pfl   constant text := '31d73422-1be9-489a-8679-58ebff85549d';
  a_t_hecke constant text := '56060bae-148c-47d1-8a76-0068f4d74b51';
  a_efs constant text[] := array[
    'e0b4ac29-3a7f-4e3b-99e7-a1ced8da532f','fb104cac-b1c3-4770-9a9c-16e0a5b3d6b1','7812de9d-40e0-44ed-b7de-e545b80d3dc1',
    'c62b2008-2eff-4b82-9109-0677ebff1f40','c3b23c13-2b77-442a-a386-65583f70462b',
    '91585d54-ff10-407d-bcd3-7a055178dec0','a34dc520-eeb6-4dac-8869-89188bbf00aa','4bd2f2a5-5c58-4381-a273-bc423d9140fc',
    'c775af73-8445-4643-8dc9-c460e0122a67','2e7d6c83-078f-4437-b286-7d612e79ca0c'];
  tabellen text[] := array['eingabefeld','eingabefeld_tabelle_spalte','term','arbeitsschritt',
    'teilschritt','auswahlfeld','auswahloption','ressourcenzeile','option_freitext_vorlage'];
  filter_sql text[] := array[
    format('offertentyp_id = %L', alt_ot),
    format('eingabefeld_id in (select id from eingabefeld where offertentyp_id = %L)', alt_ot),
    format('offertentyp_id = %L', alt_ot),
    format('offertentyp_id = %L', alt_ot),
    format('arbeitsschritt_id in (select id from arbeitsschritt where offertentyp_id = %L)', alt_ot),
    format('teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot),
    format('auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot),
    format('option_id in (select o.id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L) or teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot, alt_ot),
    format('option_id in (select o.id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L) or teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot, alt_ot)
  ];
  i int; j jsonb; txt text; u text; r record; n_neu text; anz int;
  t_pfl uuid; t_hecke uuid;
  ef_pfl uuid := gen_random_uuid(); sp_pfl uuid := gen_random_uuid();
  ef_hecke uuid := gen_random_uuid(); sp_hecke uuid := gen_random_uuid();
begin
  if exists (select 1 from offertentyp where name = 'Bepflanzung (alt)') then
    raise exception 'Vorlage «Bepflanzung (alt)» gibt es schon - Umbau lief bereits.';
  end if;

  create temp table _map (alt text primary key, neu text not null) on commit drop;
  create temp table _opt (id uuid primary key, gruppe text, ef uuid, sp uuid, wort text) on commit drop;

  -- 1) Neue Ids (auch für Optionsgruppen-Ids, damit die Gruppen nicht über zwei Vorlagen geteilt sind)
  insert into _map values (alt_ot::text, neu_ot::text);
  for i in 1 .. array_length(tabellen, 1) loop
    for r in execute format('select id from %I where %s', tabellen[i], filter_sql[i]) loop
      insert into _map values (r.id::text, gen_random_uuid()::text) on conflict do nothing;
    end loop;
  end loop;
  for r in execute format('select distinct optionsgruppe_id as id from auswahloption where optionsgruppe_id is not null and %s', filter_sql[7]) loop
    insert into _map values (r.id::text, gen_random_uuid()::text) on conflict do nothing;
  end loop;

  -- 2) Vorlage: alte umbenennen + ausblenden, neue übernimmt Name und Platz
  select to_jsonb(o) into j from offertentyp o where o.id = alt_ot;
  update offertentyp set name = 'Bepflanzung (alt)', ausgeblendet = true where id = alt_ot;
  j := j || jsonb_build_object('erstellt_am', now(), 'papierkorb_am', null, 'id', neu_ot, 'name', 'Bepflanzung', 'ausgeblendet', false);
  insert into offertentyp select * from jsonb_populate_record(null::offertentyp, j);

  -- 3) Struktur kopieren, alle uuid-Verweise (auch in Formel-JSONs) umhängen
  for i in 1 .. array_length(tabellen, 1) loop
    for r in execute format('select to_jsonb(x) as j from %I x where %s', tabellen[i], filter_sql[i]) loop
      j := r.j;
      if j ? 'offertentyp_id' then j := jsonb_set(j, '{offertentyp_id}', to_jsonb(neu_ot::text)); end if;
      txt := j::text;
      for u in select distinct (regexp_matches(txt, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'g'))[1] loop
        select m.neu into n_neu from _map m where m.alt = u;
        if n_neu is not null then txt := replace(txt, u, n_neu); end if;
      end loop;
      execute format('insert into %I select * from jsonb_populate_record(null::%I, $1)', tabellen[i], tabellen[i]) using txt::jsonb;
    end loop;
  end loop;
  select neu::uuid into t_pfl from _map where alt = a_t_pfl;
  select neu::uuid into t_hecke from _map where alt = a_t_hecke;

  -- 4) Neue Tabellen
  insert into eingabefeld (id, offertentyp_id, name, einheit, typ, ist_tabelle, ist_titel, ausgeblendet, reihenfolge, zusatztext_moeglich, flaechenformel_moeglich)
  values (ef_pfl, neu_ot, 'Pflanzflächen', '', 'zahl', true, false, false, 1, false, false),
         (ef_hecke, neu_ot, 'Hecken', '', 'zahl', true, false, false, 6, false, false);
  insert into eingabefeld_tabelle_spalte (id, eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, flaechenformel_moeglich, formel_modus)
  values (sp_pfl, ef_pfl, 'Fläche', 'm²', 1, false, true, 'baukasten'),
         (sp_hecke, ef_hecke, 'Länge', 'm', 1, false, false, 'baukasten');

  -- 5) Optionen, die mit den Totals rechnen → Tabellenverweis
  insert into _opt
  select distinct o.id,
         case when t.ref = t_hecke then 'hecke' when a.name ilike 'Mulch%' then 'mulch' else 'pflanzung' end,
         case when t.ref = t_hecke then ef_hecke else ef_pfl end,
         case when t.ref = t_hecke then sp_hecke else sp_pfl end,
         case when t.ref = t_hecke then 'Hecke' else 'Pflanzfläche' end
  from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
  join arbeitsschritt a on a.id = ts.arbeitsschritt_id
  join ressourcenzeile rz on rz.option_id = o.id
  cross join lateral (select unnest(array[t_pfl, t_hecke]) ref) t
  where a.offertentyp_id = neu_ot and rz.menge_ausdruck::text like '%' || t.ref::text || '%';

  if (select count(*) from (select id from _opt group by id having count(distinct gruppe) > 1) x) > 0 then
    raise exception 'Abbruch: eine Option rechnet mit Pflanzfläche UND Hecke.';
  end if;
  -- jede Zeile einer solchen Option muss mit dem Total rechnen (sonst würde sie neu mit der Fläche multipliziert)
  select count(*) into anz from ressourcenzeile rz join _opt o on o.id = rz.option_id
   where rz.menge_ausdruck is not null and rz.menge_ausdruck::text not like '%' || t_pfl::text || '%' and rz.menge_ausdruck::text not like '%' || t_hecke::text || '%';
  if anz > 0 then raise exception 'Abbruch: % Ressourcenzeilen ohne Total in Verweis-Optionen.', anz; end if;
  select count(*) into anz from auswahloption ao join _opt o on o.id = ao.id where ao.mengenoption or ao.tabellenverweis is not null;
  if anz > 0 then raise exception 'Abbruch: % Optionen sind schon Mengen-/Verweis-Optionen.', anz; end if;

  update auswahloption ao set tabellenverweis = jsonb_build_array(jsonb_build_object(
      'eingabefeld_id', o.ef, 'spalte_id', o.sp, 'gruppe', o.gruppe, 'wort', o.wort))
    from _opt o where o.id = ao.id;
  update auswahloption ao set mehrfachauswahl = true from _opt o where o.id = ao.id and o.gruppe = 'mulch';

  -- Formel pro m² / pro m: Total → 1
  update ressourcenzeile rz
     set menge_ausdruck = regexp_replace(rz.menge_ausdruck::text,
           '\{\s*"id"\s*:\s*"(' || t_pfl::text || '|' || t_hecke::text || ')"\s*,\s*"ref"\s*:\s*"term"\s*\}', '{"lit": 1}', 'g')::jsonb
   where rz.option_id in (select id from _opt);

  -- 6) Alte Felder und Totals in der Kopie entfernen
  delete from term where id in (t_pfl, t_hecke);
  delete from eingabefeld where id in (select neu::uuid from _map where alt = any (a_efs));

  -- 7) Kontrolle: nichts in der neuen Vorlage verweist mehr auf entfernte Ids
  select count(*) into anz from ressourcenzeile rz
   where (rz.menge_ausdruck::text like '%' || t_pfl::text || '%' or rz.menge_ausdruck::text like '%' || t_hecke::text || '%');
  if anz > 0 then raise exception 'Abbruch: % Zeilen verweisen noch auf die Totals.', anz; end if;

  raise notice 'Fertig: Bepflanzung neu (id %), % Verweis-Optionen.', neu_ot, (select count(*) from _opt);
end $$;
