-- Regenwassertank: neuer Arbeitsschritt "Zusatzarbeiten" > Teilschritt "Anschlussleitungen graben" >
-- Option "PP-Leitungen verlegen" (Mengenoption = Anzahl Tageseinsaetze, Einheit neu: "Tag").
-- Ein Tageseinsatz: Polier + Gartenarbeiter je 9 Std., Raupenbagger M 3 Std., 1 m3 Aushub (Deponie, Abfuhr ueber
-- Lieferwagen-Karte, keine Mulden), PP-Rohr Awadukt Ø125 15 m, 3 Doppelmuffen, 3 Bogen 45°.
-- Neue Option ist Zusatzoption (mehrfachauswahl), nicht vorgewaehlt.
do $$
declare
  ot uuid := '35764680-9e7a-480a-b765-7a8fe488b054';      -- Regenwassertank
  as_id uuid := gen_random_uuid(); ts_id uuid := gen_random_uuid(); af_id uuid := gen_random_uuid(); opt uuid := gen_random_uuid();
  j jsonb; r record; n int;
  rz_vorlage uuid := '814d893f-3672-48b7-9e8e-410abf86f554';   -- Ausstecken vorbereiten, Zeile 1 (Struktur-Vorlage)
begin
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Zusatzarbeiten') then
    raise exception 'Arbeitsschritt Zusatzarbeiten existiert schon';
  end if;

  if not exists (select 1 from einheit where code = 'Tag') then
    insert into einheit (code, name, reihenfolge, im_pflegetool) values ('Tag', 'Tageseinsatz', 15, false);
  end if;

  select to_jsonb(s) into j from arbeitsschritt s where s.id = 'f0debff5-8166-4b10-8492-a4e4cfa3aa58';
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt,
    j || jsonb_build_object('id', as_id, 'name', 'Zusatzarbeiten', 'reihenfolge', 3, 'erstellt_am', now()));

  select to_jsonb(t) into j from teilschritt t where t.id = '666ea75f-0f19-40b3-831c-b1495dc70158';
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt,
    j || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'name', 'Anschlussleitungen graben', 'reihenfolge', 1));

  select to_jsonb(a) into j from auswahlfeld a where a.id = 'e513b25c-edba-4fed-8f12-8e28d2a13879';
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld,
    j || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Anschlussleitungen', 'reihenfolge', 1));

  select to_jsonb(o) into j from auswahloption o where o.id = 'ab665f76-d18a-4ce2-b37f-f9f19931ab3b';
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', 'PP-Leitungen verlegen', 'reihenfolge', 1,
      'ist_standard', false, 'mehrfachauswahl', true, 'mengenoption', true,
      'mengenoption_einheit', 'Tag', 'mengenoption_standardmenge', 1,
      'hinweistext', E'Menge = Anzahl Tageseinsätze\nPro Tag: 15 m PP-Rohr, 3 Muffen, 3 Bogen, 1 m³ Aushub',
      'beschreibung', 'Anschlussleitungen graben und PP-Leitungen verlegen. Inkl. Material und Entsorgung des Aushubs.'));

  -- Zeilen: (reihenfolge, kategorie, artikel, menge, einheit)
  for r in
    select * from (values
      (1, 'personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a'::uuid, 9,  'Std.'),   -- Polier / Vorarbeiter
      (2, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81'::uuid, 9,  'Std.'),   -- Gartenarbeiter
      (3, 'material', 'e08b2087-b590-4f3a-bbc0-c83520cc1e24'::uuid, 1,  'm³'),     -- Deponiegebuehren Mat. getrennt, Direktfuhre
      (4, 'material', '139894ae-6ab2-425b-b2cb-77594a39c6c1'::uuid, 15, 'Stk.'),   -- PP Kanalrohr Awadukt Ø125 (Preis im Artikelstamm je m, Einheit steht auf Stk.)
      (5, 'material', '9889bcf2-aa7a-41c8-925d-e10866ce9328'::uuid, 3,  'Stk.'),   -- PP Doppelmuffe Ø125
      (6, 'material', '4c5f7f0d-7a35-4db8-a640-f14bdedff47d'::uuid, 3,  'Stk.'),   -- PP Bogen 45° Ø125
      (7, 'maschine', 'f5cad0dd-3699-4dcf-bce1-f644825b7a98'::uuid, 3,  'Std.')    -- Raupenbagger M
    ) as v(rf, kat, art, menge, einh)
  loop
    select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = rz_vorlage;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      j || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat,
        'artikel_id', r.art, 'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh)));
  end loop;

  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 7 then raise exception 'Erwartet 7 Zeilen, angelegt %', n; end if;
end $$;
