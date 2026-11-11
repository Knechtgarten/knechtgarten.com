-- Pool/Wassergarten › Poolabdeckung: Oberflur-Abdeckung mit Holzverkleidung statt Aquadeck-Kunststoffverkleidung
-- 1) Option «Abdeckung Oberflur Holzverkleidung» = Kopie von «Abdeckung Oberflur inkl. Verkleidung»
--    ohne Staffel «Verkleidung Aquadeck Oberflur», Arbeitszeit 22 statt 10 Std.
-- 2) Gruppe «Holzverkleidung» (Mehrfachauswahl = mit der Abdeckung kombinierbar, innerhalb nur ein Holz):
--    5 Hölzer wie Sitzelement Holzdeck, Mengen-Option in m², Holz 1 m²/m² + 15 % Verschnitt,
--    Stirnverkleidung Motorseite pauschal CHF 300 (von der Menge ausgenommen)
-- 3) Holzdeck › Sitzelement «Thermokiefer»: Artikel Thermo Kiefer statt Douglasie
do $$
declare
  alt_opt constant uuid := '2fb35234-f437-4c8f-aa35-0db6fea56131';
  af_id   constant uuid := 'fe3bf9d9-c005-4c60-a1cc-2a9bd7c78e46';
  staffel_verkleidung constant uuid := '62b0a311-de54-4a6e-af58-3a7516f9bf53';
  neu_opt uuid := gen_random_uuid();
  grp uuid := gen_random_uuid();
  r record; h record; o uuid; nr int := 6;
begin
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name = 'Abdeckung Oberflur Holzverkleidung') then
    raise exception 'Holzverkleidung gibt es schon.';
  end if;

  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    (select to_jsonb(x) from auswahloption x where x.id = alt_opt)
    || jsonb_build_object('id', neu_opt, 'name', 'Abdeckung Oberflur Holzverkleidung', 'reihenfolge', 5, 'beschreibung', null));
  for r in select * from ressourcenzeile where option_id = alt_opt and staffelgruppe_id is distinct from staffel_verkleidung loop
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu_opt)
      || case when r.kategorie = 'personal' then jsonb_build_object('menge_ausdruck', '{"lit": 22, "_einheit": "Std."}'::jsonb) else '{}'::jsonb end);
  end loop;

  for h in select * from (values
      ('Accoya Natur', 'dabc6280-f630-471e-96ad-fe0c5fd266ca'::uuid),
      ('Accoya grau',  'd673d795-2819-49e0-9614-b7c4601f4565'::uuid),
      ('Douglasie',    'c8b90361-0bc7-41ad-ad14-0b802b89f763'::uuid),
      ('Thermokiefer', '066d81e4-b895-4dd5-b3bd-a9383c8c35fe'::uuid),
      ('Kebony',       'b4c5cc56-6169-44e4-9f48-4e2ae36b7983'::uuid)) v(name, artikel)
  loop
    o := gen_random_uuid();
    insert into auswahloption (id, auswahlfeld_id, name, reihenfolge, mehrfachauswahl, mengenoption, mengenoption_einheit, optionsgruppe_id, optionsgruppe_name)
    values (o, af_id, h.name, nr, true, true, 'm²', grp, 'Holzverkleidung');
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, verschnitt_prozent, reihenfolge)
    values (o, 'material', h.artikel, '{"lit": 1, "_einheit": "m²"}'::jsonb, 15, 1);
    -- Quelle: Artikel «Pauschale Hilfsmaterial», Bezeichnung und Preis überschrieben
    insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, preis_override, menge_ausdruck, mengenoption_ausgenommen, reihenfolge)
    values (o, 'material', '612dab28-0773-4c01-b315-50e15365e8a8', 'Stirnverkleidung Holz Motorseite, pauschal', 300, '{"lit": 1, "_einheit": "Pauschale"}'::jsonb, true, 2);
    nr := nr + 1;
  end loop;

  -- Holzdeck: Sitzelement Thermokiefer rechnete mit Douglasie
  update ressourcenzeile rz set artikel_id = '066d81e4-b895-4dd5-b3bd-a9383c8c35fe'
    from auswahloption ao, auswahlfeld af, teilschritt ts, arbeitsschritt a, offertentyp ot
   where rz.option_id = ao.id and ao.auswahlfeld_id = af.id and af.teilschritt_id = ts.id and ts.arbeitsschritt_id = a.id and a.offertentyp_id = ot.id
     and not ot.ausgeblendet and ot.name ilike 'Holzdeck%' and ts.name = 'Sitzelement oben und eine Seite verkleidet'
     and ao.name = 'Thermokiefer' and rz.artikel_id = 'c8b90361-0bc7-41ad-ad14-0b802b89f763';
end $$;
