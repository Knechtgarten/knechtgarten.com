-- Neue Offertenvorlage "Regenwassertank" (Nutzerwunsch 2026-10-28), Berechnungsmodell Formel wie Pool/Wassergarten:
--  1. Arbeitsschritt "Vorarbeiten Ausstecken" = Kopie aus Pool/Wassergarten (Teilschritt Ausstecken, Option "Ausstecken vorbereiten").
--  2. Arbeitsschritt "Regenwassertank liefern und montieren" mit Teilschritt "Regenwassertank" und der Option "5000 L Tank",
--     aufgebaut wie "Zusatz Ueberlaufpool": Polier/Vorarbeiter Wassergaerten + Gartenarbeiter, Pauschale Hilfsmaterial, PLATIN Flachtank 5000 L,
--     Deponiegebuehr, Raupenbagger M, Raupendumper M. NEU: Rundkies 16/32 (3 m3) + Kies-Transport zum Hinterfuellen.
--     Nicht uebernommen: Rohr, Kugelventile, Boegen, 3-Wege-Ventil, Mulde, ThermoWhite, Sickerbeton.
-- Weitere Tankgroessen folgen spaeter als weitere Optionen.
do $$
declare
  pool constant uuid := '83bf9ae8-3095-4194-a9bb-4ea2dc08473e';
  ot uuid := gen_random_uuid();
  as_alt uuid; as1 uuid := gen_random_uuid(); as2 uuid := gen_random_uuid();
  t record; af record; o record; rz record; j jsonb;
  t_new uuid; af_new uuid; o_new uuid;
  src_opt uuid; src_kies uuid; opt uuid := gen_random_uuid(); ts2 uuid := gen_random_uuid(); af2 uuid := gen_random_uuid();
  a_kies uuid; n int;
begin
  if exists (select 1 from offertentyp where name = 'Regenwassertank') then raise exception 'Regenwassertank existiert schon'; end if;

  -- Offertentyp
  insert into offertentyp (id, name, berechnungsmodell, icon_key, farbe_key, reihenfolge, vorarbeiter_typ_standard, zugaenglichkeit_aktiv, ausgeblendet)
    values (ot, 'Regenwassertank', 'formel', 'tropfen', 'hellblau', 6, 'pool', false, false);

  -- 1) Arbeitsschritt aus Pool/Wassergarten kopieren (tief)
  select id into as_alt from arbeitsschritt where offertentyp_id = pool and name = 'Vorarbeiten Ausstecken';
  if as_alt is null then raise exception 'Quell-Arbeitsschritt fehlt'; end if;
  select to_jsonb(a) into j from arbeitsschritt a where a.id = as_alt;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, j || jsonb_build_object('id', as1, 'offertentyp_id', ot, 'reihenfolge', 1));
  for t in select * from teilschritt where arbeitsschritt_id = as_alt loop
    t_new := gen_random_uuid();
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt, to_jsonb(t) || jsonb_build_object('id', t_new, 'arbeitsschritt_id', as1, 'anzeige_eingabefeld_id', null, 'anzeige_term_id', null));
    for rz in select * from ressourcenzeile where teilschritt_id = t.id and option_id is null loop
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'teilschritt_id', t_new));
    end loop;
    for af in select * from auswahlfeld where teilschritt_id = t.id loop
      af_new := gen_random_uuid();
      insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, to_jsonb(af) || jsonb_build_object('id', af_new, 'teilschritt_id', t_new));
      for o in select * from auswahloption where auswahlfeld_id = af.id loop
        o_new := gen_random_uuid();
        insert into auswahloption select * from jsonb_populate_record(null::auswahloption, to_jsonb(o) || jsonb_build_object('id', o_new, 'auswahlfeld_id', af_new));
        for rz in select * from ressourcenzeile where option_id = o.id loop
          insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', o_new));
        end loop;
      end loop;
    end loop;
  end loop;

  -- 2) Regenwassertank liefern und montieren
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, j || jsonb_build_object('id', as2, 'offertentyp_id', ot, 'name', 'Regenwassertank liefern und montieren', 'reihenfolge', 2));
  insert into teilschritt (id, arbeitsschritt_id, name, reihenfolge, ausgeblendet, ist_belag) values (ts2, as2, 'Regenwassertank', 1, false, false);
  insert into auswahlfeld (id, teilschritt_id, name, reihenfolge) values (af2, ts2, 'Regenwassertank', 1);

  select ao.id into src_opt from auswahloption ao where ao.auswahlfeld_id = '4c4282a2-3aa8-4f92-b978-48bee555f365' and ao.name = 'Zusatz Überlaufpool';
  if src_opt is null then raise exception 'Option Zusatz Überlaufpool fehlt'; end if;
  select to_jsonb(ao) into j from auswahloption ao where ao.id = src_opt;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j || jsonb_build_object('id', opt, 'auswahlfeld_id', af2, 'name', '5000 L Tank', 'reihenfolge', 1,
    'mehrfachauswahl', false, 'beschreibung', 'Regenwassertank 5000 Liter liefern und montieren. Inkl. Aushub und Entsorgung, Hinterfüllung mit Rundkies.'));

  n := 0;
  for rz in select r.* from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = src_opt and (
        a.bezeichnung like 'Polier / Vorarbeiter Wassergärten%' or a.bezeichnung = 'Gartenarbeiter' or a.bezeichnung = 'Pauschale Hilfsmaterial'
        or a.bezeichnung like 'PLATIN Flachtank 5000 L%' or a.bezeichnung like 'Deponiegebühren Mat. getrennt%' or a.bezeichnung = 'Raupenbagger M' or a.bezeichnung = 'Raupendumper M')
      order by r.reihenfolge loop
    n := n + 1;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', n));
  end loop;
  if n <> 7 then raise exception 'Erwartet 7 Zeilen aus Zusatz Überlaufpool, uebernommen %', n; end if;

  -- Rundkies 16/32 + Kies-Transport (wie Hinterfuellung beim Pool), je 3 m3 fest
  select ao.id into src_kies from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
   where ar.offertentyp_id = pool and ar.name = 'Betonkragen und Hinterfüllung' and ts.name = 'Hinterfüllung' and ao.name = 'Rundkies';
  if src_kies is null then raise exception 'Option Rundkies (Hinterfüllung) fehlt'; end if;
  for rz in select r.* from ressourcenzeile r left join artikel a on a.id = r.artikel_id left join sonderposition_typ st on st.id = r.sonderposition_typ_id
             where r.option_id = src_kies and (a.bezeichnung = 'Rundkies 16/32 mm' or st.name = 'Kies-Transport') order by r.reihenfolge loop
    n := n + 1;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', n,
      'menge_ausdruck', jsonb_build_object('lit', 3, '_einheit', 'm³')));
  end loop;
  if n <> 9 then raise exception 'Erwartet 9 Zeilen, erzeugt %', n; end if;
end $$;
