-- Pooloptionen: Vorauswahl "Gegenstromanlage Standard" (Button in Tool A): Einbaunische Polypropylen + Blende ABS anthrazit.
-- Die Anlage (EVA 175/225/275 mit Controller) bleibt Handwahl.
do $$
declare ot uuid; vw uuid := gen_random_uuid(); n int;
begin
  select id into ot from offertentyp where name = 'Pooloptionen' and papierkorb_am is null;
  if ot is null then raise exception 'Offertentyp Pooloptionen nicht gefunden'; end if;
  if exists (select 1 from vorauswahl where offertentyp_id = ot and name = 'Gegenstromanlage Standard') then raise exception 'Vorauswahl existiert schon'; end if;
  insert into vorauswahl (id, offertentyp_id, name) values (vw, ot, 'Gegenstromanlage Standard');
  insert into vorauswahl_option (vorauswahl_id, option_id)
    select vw, ao.id from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
      join arbeitsschritt s on s.id = ts.arbeitsschritt_id
     where s.offertentyp_id = ot and s.name = 'Gegenstromanlage' and ao.name in ('Nische aus Polypropylen', 'Blende ABS anthrazit');
  get diagnostics n = row_count;
  if n <> 2 then raise exception 'Erwartet 2 Optionen, angelegt %', n; end if;
end $$;
