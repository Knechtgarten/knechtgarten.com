-- Regenwassertank > Zusatzarbeiten > Anschlussleitungen graben: statt einer Option jetzt drei Optionen
-- "Bagger S / M / L" (je Mengenoption "Tag", Dezimalzahlen moeglich), Auswahlfeld heisst "PP-Leitungen verlegen".
-- Inhalt pro Tag unveraendert; nur der Raupenbagger-Artikel unterscheidet sich. Optionen schliessen sich gegenseitig aus.
-- PP-Rohr: 15 m (Preis im Artikelstamm je Meter).
do $$
declare
  af_id uuid; m_id uuid; j jsonb; neu uuid; r record; n int;
begin
  select ao.id, ao.auswahlfeld_id into m_id, af_id
    from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
   where s.offertentyp_id = '35764680-9e7a-480a-b765-7a8fe488b054' and s.name = 'Zusatzarbeiten' and ao.name = 'PP-Leitungen verlegen';
  if m_id is null then raise exception 'Option PP-Leitungen verlegen nicht gefunden'; end if;
  if exists (select 1 from offerte_auswahl where option_id = m_id) then raise exception 'Option wird schon in Offerten verwendet'; end if;

  update auswahlfeld set name = 'PP-Leitungen verlegen' where id = af_id;

  update auswahloption set name = 'Bagger M', reihenfolge = 2, mehrfachauswahl = false,
    hinweistext = E'Menge = Anzahl Tageseinsätze (auch 0.5 oder 1.5)\nPro Tag: 15 m PP-Rohr, 3 Muffen, 3 Bogen, 1 m³ Aushub, Bagger 3 Std.'
   where id = m_id;

  -- PP-Rohr: Meter statt Stueck
  update ressourcenzeile set menge_ausdruck = '{"lit": 15, "_einheit": "m"}'::jsonb
   where option_id = m_id and artikel_id = '139894ae-6ab2-425b-b2cb-77594a39c6c1';

  for r in select * from (values ('Bagger S', 1, '2e2323d0-3244-4158-99c1-dd54a0e099f9'::uuid), ('Bagger L', 3, 'bf15228b-109a-449a-b67c-086a711dd27a'::uuid)) as v(nm, rf, bagger)
  loop
    neu := gen_random_uuid();
    select to_jsonb(o) into j from auswahloption o where o.id = m_id;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
      j || jsonb_build_object('id', neu, 'name', r.nm, 'reihenfolge', r.rf));
    insert into ressourcenzeile
      select (jsonb_populate_record(null::ressourcenzeile,
        to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu,
          'artikel_id', case when rz.kategorie = 'maschine' then r.bagger else rz.artikel_id end))).*
        from ressourcenzeile rz where rz.option_id = m_id;
    select count(*) into n from ressourcenzeile where option_id = neu;
    if n <> 7 then raise exception '% : erwartet 7 Zeilen, angelegt %', r.nm, n; end if;
  end loop;
end $$;
