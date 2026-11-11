-- Beläge, Hartflächen › Belagsfläche Naturstein: «Bahnen bruchroh» und «formwild» wie die Pflastersteine auftrennen.
-- Bestehende Teilschritte (Bettung Splitt) → «… in Splitt», Splitt 2/4 mm 4 cm (wie Pflaster in Splitt).
-- Neu je eine Kopie «… in Splittbeton» mit Sickerbeton 200 kg/m3 4–8 mm, 6 cm (bisherige Schichtstärke).
do $$
declare
  as_id uuid := '37e98118-f9a7-4067-a70e-521354dce163';
  splitt48 uuid := '749261e1-5270-4e16-946a-76e347f034cd';
  splitt24 uuid := '86d6deb4-d019-415c-b508-9d3fd3a69681';
  sicker uuid := '251abe8d-d7d4-4cab-8b8a-306ea35a4918';
  q record; ts_neu uuid; af record; af_neu uuid; ao record; ao_neu uuid; r record;
begin
  for q in select * from (values
      ('e18f6632-b821-48db-b6ce-91575dff9910'::uuid, 'Natursteinbelag Bahnen bruchroh', 2, 3),
      ('30781d99-cb67-4459-a953-96fcae90da85'::uuid, 'Natursteinbelag formwild', 4, 5)) v(id, name, rf_beton, rf_splitt)
  loop
    -- Kopie = Splittbeton
    ts_neu := gen_random_uuid();
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt,
      (select to_jsonb(t) from teilschritt t where t.id = q.id) || jsonb_build_object('id', ts_neu, 'name', q.name || ' in Splittbeton', 'reihenfolge', q.rf_beton));
    for af in select * from auswahlfeld where teilschritt_id = q.id loop
      af_neu := gen_random_uuid();
      insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld,
        to_jsonb(af) || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', q.name || ' in Splittbeton'));
      for ao in select * from auswahloption where auswahlfeld_id = af.id loop
        ao_neu := gen_random_uuid();
        insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
          to_jsonb(ao) || jsonb_build_object('id', ao_neu, 'auswahlfeld_id', af_neu));
        for r in select * from ressourcenzeile where option_id = ao.id loop
          insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
            to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', ao_neu)
            || case when r.artikel_id = splitt48 then jsonb_build_object('artikel_id', sicker, 'verschnitt_prozent', 5) else '{}'::jsonb end);
        end loop;
        insert into option_freitext_vorlage select (jsonb_populate_record(null::option_freitext_vorlage,
          to_jsonb(f) || jsonb_build_object('id', gen_random_uuid(), 'option_id', ao_neu, 'teilschritt_id', ts_neu))).*
          from option_freitext_vorlage f where f.option_id = ao.id;
      end loop;
    end loop;

    -- Bestehender = Splitt, dünnere Bettung
    update teilschritt set name = q.name || ' in Splitt', reihenfolge = q.rf_splitt where id = q.id;
    update auswahlfeld set name = q.name || ' in Splitt' where teilschritt_id = q.id and name = q.name;
    update ressourcenzeile set artikel_id = splitt24, menge_ausdruck = '{"lit": 0.04}'::jsonb, verschnitt_prozent = 5
      where artikel_id = splitt48 and option_id in (select ao2.id from auswahloption ao2 join auswahlfeld af2 on af2.id = ao2.auswahlfeld_id where af2.teilschritt_id = q.id);
  end loop;
end $$;
