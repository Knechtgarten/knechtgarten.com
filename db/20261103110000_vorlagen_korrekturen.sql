-- Korrekturen aus der Vorlagen-Prüfung vom 2026-11-03
do $$
declare
  n int; a_bodendose uuid; a_service uuid; a_jumbo uuid; af_id uuid; as_id uuid;
begin
  -- 1. Bepflanzung: Atelier Vierkant U60-grau, Gartenarbeiter 0.4 (wie U60-black)
  update ressourcenzeile rz set menge_ausdruck = jsonb_set(menge_ausdruck, '{lit}', '0.4')
  where rz.option_id in (select o.id from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id
      where ot.name='Bepflanzung' and t.name='Atelier Vierkant U-Form' and o.name='U60-grau')
    and rz.artikel_id in (select id from artikel where bezeichnung='Gartenarbeiter')
    and (rz.menge_ausdruck->>'lit')::numeric = 0.2;
  get diagnostics n = row_count; if n <> 1 then raise exception 'U60-grau: % Zeilen', n; end if;

  -- 2. Bewässerung, Boxen, Bodendose: Bodendose Alu statt Ventilkasten JUMBO
  select id into a_bodendose from artikel where artikelnummer_knecht='GRTTER_B010';
  select id into a_jumbo from artikel where artikelnummer_knecht='AQUATE_7-130';
  update ressourcenzeile rz set artikel_id = a_bodendose
  where rz.artikel_id = a_jumbo and rz.option_id in (select o.id from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id
      where ot.name='Bewässerung' and t.name='Boxen' and o.name='Bodendose');
  get diagnostics n = row_count; if n <> 1 then raise exception 'Bodendose: % Zeilen', n; end if;

  -- 4. Holzdeck: Betonsturz 10/6.5 L207cm wird je Meter verrechnet, 1 Stück = 2.07 m
  update ressourcenzeile rz set menge_ausdruck = '{"lit": 2.07, "_einheit": "m"}'::jsonb
  where rz.artikel_id = (select id from artikel where artikelnummer_knecht='HGC_100106066')
    and rz.menge_ausdruck ? 'lit' and (rz.menge_ausdruck->>'lit')::numeric = 1
    and rz.option_id in (select o.id from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id where ot.name='Holzdeck');
  get diagnostics n = row_count; raise notice 'Betonsturz-Zeilen angepasst: %', n;

  -- 5. Bewässerung, Grabarbeiten: Team Servicetechniker = Servicetechniker statt Polier
  select id into a_service from artikel where artikelnummer_knecht='KNECHT_000016';
  update ressourcenzeile rz set artikel_id = a_service
  where rz.kategorie='personal' and rz.artikel_id in (select id from artikel where bezeichnung like 'Polier / Vorarbeiter%')
    and rz.option_id in (select o.id from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id
      where ot.name='Bewässerung' and a.name='Grabarbeiten' and o.name='Team Servicetechniker Std.');
  get diagnostics n = row_count; if n <> 1 then raise exception 'Team Servicetechniker: % Zeilen', n; end if;

  -- 6. EVA Blende V4A Q2 d110: Händlerpreis 66 (schon erfasst), UVP 112 = Verkaufspreis
  update artikel set vp_lieferant = 112, vp_knecht = 112 where artikelnummer_knecht='AQUASOL_074330' and ep_lieferant = 66;
  get diagnostics n = row_count; if n <> 1 then raise exception 'AQUASOL_074330 nicht gefunden'; end if;

  -- 7a. Pool Zwischentransport: Budget 1500 statt 1200 (Tippfehler im Text korrigiert)
  update option_freitext_vorlage set preis_vorschlag = 1500, bezeichnung = 'Budgetbetrag für Zwischentransport und Umladen'
  where id = 'a54cb0e6-6292-4510-8fa4-d5208579d90a';
  get diagnostics n = row_count; if n <> 1 then raise exception 'Zwischentransport nicht gefunden'; end if;

  -- 7b. Rasen: Arbeitsschritt Vorbereitungsarbeiten löschen (leer, in keiner Offerte verwendet)
  delete from arbeitsschritt where id in (select a.id from arbeitsschritt a join offertentyp ot on ot.id=a.offertentyp_id where ot.name='Rasen' and a.name='Vorbereitungsarbeiten');
  get diagnostics n = row_count; if n <> 1 then raise exception 'Rasen Vorbereitung: % gelöscht', n; end if;

  -- Quervergleich: Kernbohrung pro Bohrung überall 1.5 Std. Polier + 1.5 Std. Gartenarbeiter
  update ressourcenzeile rz set menge_ausdruck = jsonb_set(menge_ausdruck, '{lit}', '1.5')
  where rz.kategorie='personal' and rz.menge_ausdruck ? 'lit' and (rz.menge_ausdruck->>'lit')::numeric = 2
    and rz.option_id in (select o.id from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id
      where (ot.name='Pool/Wassergarten' and o.name='Kernbohrung') or (ot.name='Bewässerung' and o.name like 'Kernbohrung für 4 Zonen%'));
  get diagnostics n = row_count; if n <> 4 then raise exception 'Kernbohrung 2->1.5: % Zeilen', n; end if;
  -- Schlammsammler: 2 Bohrungen = 3 Std. statt 4
  update ressourcenzeile rz set menge_ausdruck = jsonb_set(menge_ausdruck, '{lit}', '3')
  where rz.kategorie='personal' and rz.menge_ausdruck ? 'lit' and (rz.menge_ausdruck->>'lit')::numeric = 4
    and rz.option_id in (select o.id from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id
      where ot.name='Regenwassertank' and t.name='Schlammsammler montieren');
  get diagnostics n = row_count; if n <> 6 then raise exception 'Schlammsammler: % Zeilen', n; end if;
  -- Kernbohrgerät wird je Bohrung (Stk.) gerechnet
  update artikel set einheit = 'Stk.' where artikelnummer_knecht='KNECHT_000172';

  -- Quervergleich: Jaco-Gefässe Befüllzeit nach Grösse wie bei Atelier (je Person)
  update ressourcenzeile rz set menge_ausdruck = jsonb_set(menge_ausdruck, '{lit}', to_jsonb(
      case when g <= 45 then 0.2 when g <= 55 then 0.3 when g <= 65 then 0.4 when g <= 75 then 0.5 when g <= 85 then 0.6 when g <= 100 then 0.8 else 1.0 end))
  from (select o.id oid, substring(o.name from '(\d+)')::int g from auswahloption o join auswahlfeld f on f.id=o.auswahlfeld_id join teilschritt t on t.id=f.teilschritt_id join arbeitsschritt a on a.id=t.arbeitsschritt_id join offertentyp ot on ot.id=a.offertentyp_id
        where ot.name='Bepflanzung' and t.name='Jaco Gefässe') x
  where rz.option_id = x.oid and rz.kategorie='personal' and (rz.menge_ausdruck->>'lit')::numeric = 0.2;
  get diagnostics n = row_count; if n <> 72 then raise exception 'Jaco: % Zeilen', n; end if;
end $$;
