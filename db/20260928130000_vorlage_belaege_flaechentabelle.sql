-- ============================================================================
-- Offertentool 2027 - Belag-Dropdown, Etappe 3
-- Neue Vorlage "Beläge, Hartflächen (neu)" als KOPIE von "Beläge, Hartflächen"
-- (id 9a6f7c22-10da-46f9-848f-72b8e1950731), die alte Vorlage bleibt unberührt.
--
-- Unterschiede der Kopie:
--  * EINE Tabelle "Flächen" statt Hartflächen + Kiesflächen:
--      Länge | Breite | Belag (Dropdown) | Aushub | Fundation | Fläche |
--      Volumen Aushub | Volumen Fundation   (Volumen pro Zeile, Auflockerung 1.2)
--  * Volumen Aushub/Fundation Total = Summe der neuen Volumen-Spalten.
--  * Belag-Teilschritte (Natursteinbelag x3) rechnen mit "Fläche dieses Belags"
--    statt Summe Hartflächen, Fugen mit "Fläche aller Beläge".
--  * Natursteinbelag-Teilschritte sind als Belag markiert (ist_belag).
-- Alles andere (Arbeitsschritte, Optionen, Artikel, Mengen-Formeln) wird 1:1 kopiert,
-- Verweise auf Eingabefelder/Spalten/Terms werden auf die neuen Ids umgehängt.
-- Läuft in EINER Transaktion: bei einem Fehler wird nichts angelegt.
-- ============================================================================
do $$
declare
  alt_ot  constant uuid := '9a6f7c22-10da-46f9-848f-72b8e1950731';
  neu_ot  uuid := gen_random_uuid();
  neuer_name constant text := 'Beläge, Hartflächen (neu)';
  -- Ids der Quell-Vorlage (aus der Abfrage vom 2026-10-17)
  a_ef_hart   constant text := '3c8b40a8-0c28-4a21-a746-c3715e859e48';
  a_ef_kies   constant text := 'd42ca7ba-c6a4-420c-9c00-484af5164507';
  a_sp_laenge constant text := '14ce9456-d8cc-4686-a93e-791fc54b9f0c';
  a_sp_breite constant text := '0c1c9f5c-6fa1-43c5-9047-a707428f1ef9';
  a_sp_fund   constant text := '49f190c6-f4f0-4d55-b4e8-e9a0ed67f322';
  a_sp_aush   constant text := '9de913cf-8688-4167-bc1b-02a7d46f1b70';
  a_sp_fl     constant text := '8cba4fdc-df02-4d4f-bbb8-ec582e3c96c5';
  a_t_aush_tot constant text := 'eb341056-a59a-4388-8e7e-c9d7661e68f1';
  a_t_fund_tot constant text := 'f0cf4a34-c0d2-4720-810f-02b3f557e08a';
  a_t_aufl     constant text := '1e580651-2aca-4978-a888-a028514ee69a';
  a_t_alte_vol constant text[] := array[
    '8beba525-8aa5-435e-873b-375578a37c5e', '852cebed-3b79-483e-a1f1-9e6457bf90ef',
    '40e071a5-6105-485d-9385-dc37ad8b09a7', '521bdc42-bc78-4c5e-be2b-353abc29ee2e'];
  tabellen text[] := array['eingabefeld','eingabefeld_tabelle_spalte','term','arbeitsschritt',
    'teilschritt','auswahlfeld','auswahloption','ressourcenzeile'];
  filter_sql text[] := array[
    format('offertentyp_id = %L', alt_ot),
    format('eingabefeld_id in (select id from eingabefeld where offertentyp_id = %L)', alt_ot),
    format('offertentyp_id = %L', alt_ot),
    format('offertentyp_id = %L', alt_ot),
    format('arbeitsschritt_id in (select id from arbeitsschritt where offertentyp_id = %L)', alt_ot),
    format('teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot),
    format('auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot),
    format('option_id in (select o.id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L) or teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = %L)', alt_ot, alt_ot)
  ];
  i int; j jsonb; txt text; u text; r record;
  n_neu text;
  ef_flaechen uuid; ef_kies_neu uuid;
  sp_laenge uuid; sp_breite uuid; sp_fund uuid; sp_aush uuid; sp_fl uuid;
  sp_belag uuid := gen_random_uuid(); sp_vol_aush uuid := gen_random_uuid(); sp_vol_fund uuid := gen_random_uuid();
  t_aufl uuid; t_aush_tot uuid; t_fund_tot uuid;
  t_belag uuid; t_belag_alle uuid;
  anz int;
begin
  if exists (select 1 from offertentyp where name = neuer_name) then
    raise exception 'Vorlage "%" gibt es schon - bitte zuerst loeschen oder umbenennen.', neuer_name;
  end if;

  create temp table _map (alt text primary key, neu text not null) on commit drop;

  -- 1) Neue Ids vergeben (erst alle, damit Verweise nach vorne/hinten aufloesbar sind)
  insert into _map values (alt_ot::text, neu_ot::text);
  for i in 1 .. array_length(tabellen, 1) loop
    for r in execute format('select id from %I where %s', tabellen[i], filter_sql[i]) loop
      insert into _map values (r.id::text, gen_random_uuid()::text);
    end loop;
  end loop;

  -- 2) Vorlage selbst
  select to_jsonb(o) into j from offertentyp o where o.id = alt_ot;
  j := j || jsonb_build_object('erstellt_am', now(), 'papierkorb_am', null,
    'id', neu_ot, 'name', neuer_name,
    'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from offertentyp), 'ausgeblendet', false);
  insert into offertentyp select * from jsonb_populate_record(null::offertentyp, j);

  -- 3) Struktur kopieren, alle uuid-Verweise (auch innerhalb der Formel-JSONs) umhaengen
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

  select neu::uuid into ef_flaechen from _map where alt = a_ef_hart;
  select neu::uuid into ef_kies_neu from _map where alt = a_ef_kies;
  select neu::uuid into sp_laenge from _map where alt = a_sp_laenge;
  select neu::uuid into sp_breite from _map where alt = a_sp_breite;
  select neu::uuid into sp_fund   from _map where alt = a_sp_fund;
  select neu::uuid into sp_aush   from _map where alt = a_sp_aush;
  select neu::uuid into sp_fl     from _map where alt = a_sp_fl;
  select neu::uuid into t_aufl    from _map where alt = a_t_aufl;
  select neu::uuid into t_aush_tot from _map where alt = a_t_aush_tot;
  select neu::uuid into t_fund_tot from _map where alt = a_t_fund_tot;

  -- 4) Eine Tabelle "Flaechen": Kiesflaechen-Tabelle weg, Hartflaechen umbauen
  update eingabefeld set name = 'Flächen' where id = ef_flaechen;
  update eingabefeld_tabelle_spalte set reihenfolge = 1 where id = sp_laenge;
  update eingabefeld_tabelle_spalte set reihenfolge = 2 where id = sp_breite;
  update eingabefeld_tabelle_spalte set reihenfolge = 4 where id = sp_aush;
  update eingabefeld_tabelle_spalte set reihenfolge = 5 where id = sp_fund;
  update eingabefeld_tabelle_spalte set reihenfolge = 6 where id = sp_fl;

  insert into eingabefeld_tabelle_spalte (id, eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ist_dropdown, dropdown_leer_label, dropdown_pflicht, formel_modus)
  values (sp_belag, ef_flaechen, 'Belag', '', 3, false, true, '– Kies / ohne Belag –', false, 'baukasten');

  insert into eingabefeld_tabelle_spalte (id, eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausdruck, formel_modus)
  values
   (sp_vol_aush, ef_flaechen, 'Volumen Aushub', 'm³', 7, true,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('op','*','args', jsonb_build_array(
        jsonb_build_object('id', sp_fl, 'ref', 'spalte'),
        jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('id', sp_aush, 'ref','spalte'), jsonb_build_object('lit', 0.01)), '_umrechnung', true))),
      jsonb_build_object('id', t_aufl, 'ref', 'term'))), 'baukasten'),
   (sp_vol_fund, ef_flaechen, 'Volumen Fundation', 'm³', 8, true,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('op','*','args', jsonb_build_array(
        jsonb_build_object('id', sp_fl, 'ref', 'spalte'),
        jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('id', sp_fund, 'ref','spalte'), jsonb_build_object('lit', 0.01)), '_umrechnung', true))),
      jsonb_build_object('id', t_aufl, 'ref', 'term'))), 'baukasten');

  -- Totals = Summe der Volumen-Spalten ueber alle Zeilen; alte 4 Volumen-Terms und Kies-Tabelle weg
  update term set ausdruck = jsonb_build_object('id', sp_vol_aush, 'ref', 'spalte') where id = t_aush_tot;
  update term set ausdruck = jsonb_build_object('id', sp_vol_fund, 'ref', 'spalte') where id = t_fund_tot;
  delete from term where id in (select neu::uuid from _map where alt = any (a_t_alte_vol));
  delete from eingabefeld where id = ef_kies_neu;

  -- 5) Systemwert-Terms (global) sicherstellen
  insert into term (offertentyp_id, name, typ, systemwert_key, einheit)
  select null, 'Fläche dieses Belags', 'systemwert', 'belag_flaeche', 'm²'
  where not exists (select 1 from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche');
  insert into term (offertentyp_id, name, typ, systemwert_key, einheit)
  select null, 'Fläche aller Beläge', 'systemwert', 'belag_flaeche_alle', 'm²'
  where not exists (select 1 from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche_alle');
  select id into t_belag from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche';
  select id into t_belag_alle from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche_alle';

  -- 6) Belag-Teilschritte (Natursteinbelag x3) und Fugen: Hartflaechen-Summe ersetzen
  update teilschritt set ist_belag = true
   where arbeitsschritt_id in (select id from arbeitsschritt where offertentyp_id = neu_ot)
     and name in ('Natursteinbelag Bahnen geflammt','Natursteinbelag Bahnen bruchroh','Natursteinbelag formwild');

  update ressourcenzeile rz
     set menge_ausdruck = regexp_replace(rz.menge_ausdruck::text,
           '\{\s*"id"\s*:\s*"' || sp_fl::text || '"\s*,\s*"ref"\s*:\s*"spalte"\s*\}',
           '{"id": "' || t_belag::text || '", "ref": "term"}', 'g')::jsonb
   where rz.menge_ausdruck is not null
     and (rz.teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id
                                 where a.offertentyp_id = neu_ot and ts.ist_belag)
          or rz.option_id in (select o.id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id
                               join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
                               where a.offertentyp_id = neu_ot and ts.ist_belag));

  update ressourcenzeile rz
     set menge_ausdruck = regexp_replace(rz.menge_ausdruck::text,
           '\{\s*"id"\s*:\s*"' || sp_fl::text || '"\s*,\s*"ref"\s*:\s*"spalte"\s*\}',
           '{"id": "' || t_belag_alle::text || '", "ref": "term"}', 'g')::jsonb
   where rz.menge_ausdruck is not null
     and (rz.teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id
                                 where a.offertentyp_id = neu_ot and ts.name = 'Fugen')
          or rz.option_id in (select o.id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id
                               join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
                               where a.offertentyp_id = neu_ot and ts.name = 'Fugen'));

  -- 7) Kontrolle: nichts darf mehr auf die Flaechen-Summe verweisen
  select count(*) into anz from ressourcenzeile rz
   where rz.menge_ausdruck::text like '%' || sp_fl::text || '%'
     and (rz.teilschritt_id in (select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = neu_ot)
          or rz.option_id in (select o.id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id
                               join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
                               where a.offertentyp_id = neu_ot));
  if anz > 0 then
    raise exception 'Abbruch: % Zeilen verweisen noch auf die Flaechen-Summe - nichts wurde angelegt.', anz;
  end if;

  raise notice 'Fertig: Vorlage "%" (id %) angelegt.', neuer_name, neu_ot;
end $$;

-- Kontrolle (separat ausfuehren): Summe der Zeilen/Formeln alt vs. neu
select o.name, count(distinct a.id) as arbeitsschritte, count(distinct ts.id) as teilschritte,
       count(distinct rz.id) as ressourcenzeilen
from offertentyp o
join arbeitsschritt a on a.offertentyp_id = o.id
left join teilschritt ts on ts.arbeitsschritt_id = a.id
left join auswahlfeld af on af.teilschritt_id = ts.id
left join auswahloption op on op.auswahlfeld_id = af.id
left join ressourcenzeile rz on rz.option_id = op.id or rz.teilschritt_id = ts.id
where o.name in ('Beläge, Hartflächen', 'Beläge, Hartflächen (neu)')
group by o.name;
