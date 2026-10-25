-- Blendmauer: kürzere Spaltentitel, "Mauer wählen" statt "Fläche", Betonmauer Coffra, Zusatzarbeiten in einem Teilschritt
do $$
declare
  ot uuid; as_v uuid; as_bl uuid; ef_bl uuid; ef_nat uuid; ts_new uuid := gen_random_uuid(); af_new uuid := gen_random_uuid(); ts_tmpl uuid; af_tmpl uuid;
  alte_af uuid[]; alte_ts uuid[]; n int; tmpl jsonb;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_v from arbeitsschritt where offertentyp_id = ot and name = 'Verblender';
  select id into as_bl from arbeitsschritt where offertentyp_id = ot and name = 'Verblendmauer (Coffra)';
  select id into ef_bl from eingabefeld where offertentyp_id = ot and name = 'Blendmauer' and ist_tabelle;
  select id into ef_nat from eingabefeld where offertentyp_id = ot and name = 'Natursteinmauer' and ist_tabelle;
  if as_v is null or as_bl is null or ef_bl is null or ef_nat is null then raise exception 'Grundlage nicht gefunden'; end if;

  -- 1. Spaltentitel
  update eingabefeld_tabelle_spalte set name = 'Fund.-Breite' where eingabefeld_id in (ef_bl, ef_nat) and name in ('Fundamentbreite');
  update eingabefeld_tabelle_spalte set name = 'Fund.-Höhe'   where eingabefeld_id = ef_bl and name = 'Fundamentdicke';
  update eingabefeld_tabelle_spalte set name = 'Fund.-Tiefe'  where eingabefeld_id = ef_nat and name = 'Fundamenttiefe';
  update eingabefeld_tabelle_spalte set name = 'Seiten', einheit = '' where eingabefeld_id = ef_bl and name = 'Verblender-Seiten';
  update eingabefeld_tabelle_spalte set name = 'Abdeckung' where eingabefeld_id = ef_bl and name = 'Abdeckung';
  update eingabefeld_tabelle_spalte set name = 'Stirnen', einheit = 'Stk' where eingabefeld_id = ef_bl and name = 'Stirnseiten';

  -- 2. Wort für das Zuordnungsfenster: "Mauer"
  update auswahloption o set tabellenverweis = (select jsonb_agg(e || jsonb_build_object('wort', 'Mauer')) from jsonb_array_elements(o.tabellenverweis) e)
   where o.tabellenverweis is not null and o.id in (
     select o2.id from auswahloption o2 join auswahlfeld f on f.id = o2.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot);

  -- 3. Betonmauer Coffra
  update teilschritt set name = 'Betonmauer Coffra' where arbeitsschritt_id = as_bl and name = 'Betonmauer';
  update auswahlfeld set name = 'Betonmauer Coffra' where name = 'Betonmauer' and teilschritt_id in (select id from teilschritt where arbeitsschritt_id = as_bl);
  update auswahloption set name = 'Coffra gepumpt' where name = 'Betonmauer gepumpt' and auswahlfeld_id in (select id from auswahlfeld where name = 'Betonmauer Coffra');
  update auswahloption set name = 'Coffra mit Lieferwagen' where name = 'Betonmauer mit Lieferwagen' and auswahlfeld_id in (select id from auswahlfeld where name = 'Betonmauer Coffra');

  -- 4. Zusatzarbeiten Blendmauer: Verputzen, Ecken, Abdeckplatte, Stirnseiten in einem Teilschritt
  select array_agg(f.id), array_agg(f.teilschritt_id) into alte_af, alte_ts from auswahlfeld f join teilschritt ts on ts.id = f.teilschritt_id
   where (ts.arbeitsschritt_id = as_bl and ts.name = 'Verputzen') or (ts.arbeitsschritt_id = as_v and ts.name in ('Geopietra Ecken', 'Abdeckplatte', 'Stirnseiten'));
  if alte_af is null or array_length(alte_af, 1) <> 4 then raise exception 'Erwartet 4 Felder, gefunden %', coalesce(array_length(alte_af, 1), 0); end if;
  select ts.id, f.id into ts_tmpl, af_tmpl from teilschritt ts join auswahlfeld f on f.teilschritt_id = ts.id where ts.id = alte_ts[1] limit 1;
  select to_jsonb(t) into tmpl from teilschritt t where t.id = ts_tmpl;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_new, 'arbeitsschritt_id', as_v, 'name', 'Zusatzarbeiten Blendmauer', 'reihenfolge', 3, 'beschreibung', null));
  select to_jsonb(f) into tmpl from auswahlfeld f where f.id = af_tmpl;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_new, 'teilschritt_id', ts_new, 'name', 'Zusatzarbeiten Blendmauer'));
  update auswahloption o set auswahlfeld_id = af_new, mehrfachauswahl = true,
         reihenfolge = case o.name when 'Verputzen einseitig' then 1 when 'Verputzen zweiseitig' then 2 when 'Ecken Toce' then 3 when 'Ecken Cascata' then 4
                                    when 'Abdeckplatte Piasentina' then 5 when 'Geopietra Abdeckung' then 6 when 'Stirnseite Cortenblech' then 7 else 8 end
   where o.auswahlfeld_id = any(alte_af);
  get diagnostics n = row_count;
  if n <> 8 then raise exception 'Erwartet 8 Optionen, verschoben %', n; end if;
  delete from auswahlfeld where id = any(alte_af);
  delete from teilschritt where id = any(alte_ts);
  update teilschritt set reihenfolge = 1 where arbeitsschritt_id = as_v and name = 'Verblender Z-Elemente';
  update teilschritt set reihenfolge = 2 where arbeitsschritt_id = as_v and name = 'Verblender Geopietra';
end $$;
