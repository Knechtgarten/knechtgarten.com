-- Pooloptionen > Gegenstromanlage: Einbaunische und Blende wandern in das Auswahlfeld der Anlage (eine Zeile in Tool A),
-- je als Optionsgruppe "Nische" bzw. "Blende" mit Mehrfachauswahl (unabhängige Einzelwahl, kombinierbar mit der Anlage).
do $$
declare
  as_id uuid; af_a uuid; n int;
  g_n uuid := gen_random_uuid(); g_b uuid := gen_random_uuid();
begin
  select s.id into as_id from arbeitsschritt s join offertentyp ot on ot.id = s.offertentyp_id where ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Gegenstromanlage';
  select af.id into af_a from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_id and ts.name = 'Gegenstromanlage';
  if as_id is null or af_a is null then raise exception 'Gegenstromanlage nicht gefunden'; end if;

  update auswahloption ao set auswahlfeld_id = af_a, mehrfachauswahl = true, optionsgruppe_id = g_n, optionsgruppe_name = 'Nische',
         name = case ao.name when 'Nische aus Polypropylen' then 'Polypropylen' else 'Edelstahl' end,
         reihenfolge = case ao.name when 'Nische aus Polypropylen' then 6 else 7 end
   where ao.name in ('Nische aus Polypropylen', 'Nische aus Edelstahl')
     and ao.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_id and ts.name = 'Einbaunische');
  get diagnostics n = row_count;
  if n <> 2 then raise exception 'Erwartet 2 Nischen, verschoben %', n; end if;
  update auswahloption ao set auswahlfeld_id = af_a, mehrfachauswahl = true, optionsgruppe_id = g_b, optionsgruppe_name = 'Blende',
         name = case ao.name when 'Blende ABS anthrazit' then 'ABS anthrazit' else 'Edelstahl' end,
         reihenfolge = case ao.name when 'Blende ABS anthrazit' then 8 else 9 end
   where ao.name in ('Blende ABS anthrazit', 'Blende Edelstahl')
     and ao.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id where ts.arbeitsschritt_id = as_id and ts.name = 'Blende');
  get diagnostics n = row_count;
  if n <> 2 then raise exception 'Erwartet 2 Blenden, verschoben %', n; end if;

  -- leere Teilschritte/Felder entfernen
  if exists (select 1 from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id where t.arbeitsschritt_id = as_id and t.name in ('Einbaunische', 'Blende')) then
    raise exception 'Alte Felder nicht leer';
  end if;
  delete from auswahlfeld where teilschritt_id in (select id from teilschritt where arbeitsschritt_id = as_id and name in ('Einbaunische', 'Blende'));
  delete from teilschritt where arbeitsschritt_id = as_id and name in ('Einbaunische', 'Blende');

  select count(*) into n from auswahloption where auswahlfeld_id = af_a;
  if n <> 9 then raise exception 'Erwartet 9 Optionen im Feld, gefunden %', n; end if;
end $$;
