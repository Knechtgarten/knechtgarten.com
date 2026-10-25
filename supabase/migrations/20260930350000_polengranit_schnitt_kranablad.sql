-- Polengranit: Grenze Grossmengen (ganze Lkw-Ladung) ab 22 m² (30er), 20 m² (40er), 18 m² (50er) Sichtfläche;
-- Kranablad als Option im Teilschritt "Transport Natursteine" (Freitext-Position, Preis von Hand: Fontarocca nennt keinen Preis, nur "auf Anfrage")
update auswahloption o set hinweistext = case
  when f.name = 'Polengranit Grossmengen franko geliefert' then
    'Ganze Lkw-Ladung, franko geliefert: sinnvoll ab ca. ' ||
    case when o.name like '30er%' then '22 m² bei 30er Blöcken (1.0 t/m²)' when o.name like '40er%' then '20 m² bei 40er Blöcken (1.15 t/m²)' else '18 m² bei 50er Blöcken (1.3 t/m²)' end ||
    ' Sichtfläche. Preis gilt für Lieferort Liestal, andere Lieferorte bei Fontarocca anfragen. Lieferung auf Paletten ohne Ablad (Kranablad: siehe Transport Natursteine).'
  else
    'Ab Lager Liestal, für Mengen unter einer ganzen Lkw-Ladung (unter ca. ' ||
    case when o.name like '30er%' then '22 m² bei 30er Blöcken' when o.name like '40er%' then '20 m² bei 40er Blöcken' else '18 m² bei 50er Blöcken' end ||
    '). Unter 3 t loses Material oder weniger als 1 Palette: Kleinmengenzuschlag CHF 40 pauschal. Die Fontarocca-Lieferung je Tonne ist als Transport separat enthalten.'
  end
 from auswahlfeld f
 where f.id = o.auswahlfeld_id and f.name in ('Polengranit Grossmengen franko geliefert', 'Polengranit Kleinmengen ab Lager Liestal');

do $$
declare af uuid; o_dir uuid; tmpl jsonb; oid uuid := gen_random_uuid();
begin
  select f.id, o.id into af, o_dir from auswahlfeld f join auswahloption o on o.auswahlfeld_id = f.id where f.name = 'Transport Natursteine' and o.name = 'Direkt (gekippt)';
  if af is null then raise exception 'Transport Natursteine nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af and name = 'Kranablad') then raise exception 'Kranablad gibt es schon'; end if;
  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_dir;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'name', 'Kranablad', 'reihenfolge', 4, 'mehrfachauswahl', true,
      'beschreibung', 'Natursteine mit Kran abladen.', 'hinweistext', 'Fontarocca liefert in der Regel ohne Ablad (Polen-, Portugal- und Lusernaquader auf Paletten). Kranablad gibt es nur auf Anfrage, ein Preis steht nicht in der Preisliste: Preis in der Offerte von Hand eintragen.'));
  insert into option_freitext_vorlage (option_id, kategorie, bezeichnung, einheit, menge_vorschlag, preis_vorschlag, reihenfolge, ist_eigene_offertenposition)
  values (oid, 'logistik', 'Kranablad Natursteine (Preis bei Fontarocca anfragen)', 'Pauschale', 1, null, 1, false);
end $$;
