-- Gartenbeleuchtung: Teilschritt «Boxen» (Wandboxen S/M/L grau + anthrazit) wie bei der Bewässerung (Steuerung > Boxen).
-- Ohne Bodenschacht Jumbo und Bodendose. Neuer Teilschritt im Arbeitsschritt «Grundinstallation, Netzteil pro Gruppe» nach «Netzteil».
-- Wandbox S grau: in der Bewässerung steht dort aktuell Bodendose Alu statt Wandbox; hier wie S anthrazit aufgebaut
-- (Wandbox S grau, Servicetechniker 1 Std., Pauschale Hilfsmaterial).
do $$
declare
  ot uuid; as_id uuid; src_ts uuid := '8519e1d8-16e4-4879-bb91-43192c734790'; src_af uuid := 'c93c936e-3662-42b7-9db9-23ee48961889';
  new_ts uuid := gen_random_uuid(); new_af uuid := gen_random_uuid(); r record; new_o uuid; z record;
  a_s_grau uuid; a_pausch uuid; a_service uuid; jo jsonb; src_s_anth uuid;
begin
  select id into ot from offertentyp where name = 'Gartenbeleuchtung' and papierkorb_am is null;
  select a.id into as_id from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Grundinstallation, Netzteil pro Gruppe';
  if ot is null or as_id is null then raise exception 'Gartenbeleuchtung/Arbeitsschritt nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name = 'Boxen') then raise exception 'Boxen existiert schon'; end if;

  insert into teilschritt select (jsonb_populate_record(null::teilschritt, to_jsonb(t) || jsonb_build_object('id', new_ts, 'arbeitsschritt_id', as_id, 'reihenfolge', 2))).*
    from teilschritt t where t.id = src_ts;
  insert into auswahlfeld select (jsonb_populate_record(null::auswahlfeld, to_jsonb(f) || jsonb_build_object('id', new_af, 'teilschritt_id', new_ts))).*
    from auswahlfeld f where f.id = src_af;

  select id into src_s_anth from auswahloption where auswahlfeld_id = src_af and name = 'Wandbox S anthrazit (2 Z)';
  select id into a_s_grau from artikel where artikelnummer_knecht = 'KNECHT_EDP 32/17 HG';
  if src_s_anth is null or a_s_grau is null then raise exception 'Vorlage S anthrazit / Artikel S grau fehlt'; end if;

  for r in select * from auswahloption where auswahlfeld_id = src_af and reihenfolge between 1 and 6 order by reihenfolge loop
    new_o := gen_random_uuid();
    insert into auswahloption select (jsonb_populate_record(null::auswahloption, to_jsonb(r) || jsonb_build_object('id', new_o, 'auswahlfeld_id', new_af))).*;
    if r.name = 'Wandbox S grau (2 Z)' then
      -- Zeilen von S anthrazit, mit Artikel S grau
      for z in select * from ressourcenzeile where option_id = src_s_anth order by reihenfolge loop
        insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile, to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', new_o,
          'teilschritt_id', case when z.teilschritt_id is null then null else new_ts end,
          'artikel_id', case when z.reihenfolge = 1 and z.kategorie = 'material' then a_s_grau else z.artikel_id end))).*;
      end loop;
    else
      for z in select * from ressourcenzeile where option_id = r.id order by reihenfolge loop
        insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile, to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', new_o,
          'teilschritt_id', case when z.teilschritt_id is null then null else new_ts end))).*;
      end loop;
    end if;
  end loop;
end $$;
