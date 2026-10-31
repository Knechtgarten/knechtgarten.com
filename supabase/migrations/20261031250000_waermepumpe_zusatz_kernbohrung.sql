-- Pooloptionen > Wärmepumpe: "Zusatz: Kernbohrung mit Pressring" (Mengenbutton = Anzahl Kernbohrungen), kombinierbar mit jeder Wärmepumpe.
-- Pro Bohrung: Polier + Gartenarbeiter je 1.5 Std., Kernbohrgerät 1 Stk., Pressring U100 für Rohre d63 1 Stk. (Kopie der Option beim Regenwassertank).
do $$
declare af_id uuid; src uuid; opt uuid := gen_random_uuid(); j jsonb; n int;
begin
  select ao.auswahlfeld_id into af_id from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
    join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Wärmepumpe (ohne Grabarbeiten)' and ao.name = 'WP-30m3';
  select ao.id into src from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
    join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Regenwassertank' and ot.papierkorb_am is null and ts.name = 'Kernbohrung mit Pressring';
  if af_id is null or src is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name = 'Zusatz: Kernbohrung mit Pressring') then raise exception 'Option existiert schon'; end if;

  select to_jsonb(x) into j from auswahloption x where x.id = src;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', 'Zusatz: Kernbohrung mit Pressring',
      'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from auswahloption where auswahlfeld_id = af_id),
      'mehrfachauswahl', true, 'optionsgruppe_id', null, 'optionsgruppe_name', null,
      'beschreibung', 'Kernbohrung für die Schlauchdurchführung erstellen und mit Pressring abdichten.',
      'hinweistext', 'Menge = Anzahl Kernbohrungen (je Bohrung ein Pressring). Nur nötig, wenn die Wärmepumpe im Haus oder Gartenhaus steht.'));
  insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile,
    to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt))).*
    from ressourcenzeile z where z.option_id = src;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 4 then raise exception 'Erwartet 4 Zeilen, angelegt %', n; end if;
end $$;
