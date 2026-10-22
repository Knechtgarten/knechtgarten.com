-- Natursteinmauer: Zuordnung pro Mauerzeile (Tabellenverweis, Gruppe "mauer") für beide Teilschritte
-- (wechselschichtig / geschichtet in Blöcken). Jede Mauerzeile hat genau eine Art; mehrere Optionen
-- können gleichzeitig gewählt sein (verschiedene Mauern). Mengen jetzt je m² der zugeordneten Zeilen.
do $$
declare
  ot uuid; as_nat uuid; ef uuid; sp_fl uuid; t_fl uuid; t_tpm uuid; a_w uuid; a_s uuid; ids uuid[]; verw jsonb; n int;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_nat from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer';
  select id into ef from eingabefeld where offertentyp_id = ot and name = 'Natursteinmauer' and ist_tabelle;
  select id into sp_fl from eingabefeld_tabelle_spalte where eingabefeld_id = ef and name = 'Fläche';
  select id into t_fl from term where offertentyp_id = ot and name = 'Sichtfläche Natursteinmauer';
  select id into t_tpm from term where offertentyp_id = ot and name = 'Tonnen pro m² Mauer';
  select id into a_w from artikel where bezeichnung = 'Plasselb Natursteinblöcke 50-100 L (Wechselschicht)';
  select id into a_s from artikel where bezeichnung = 'Plasselb Natursteinblöcke 300-500 L (Schichten)';
  if ef is null or sp_fl is null or t_fl is null or t_tpm is null or a_w is null or a_s is null then raise exception 'Grundlage nicht gefunden'; end if;
  select array_agg(o.id) into ids from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id
   where ts.arbeitsschritt_id = as_nat and ts.name in ('Natursteinmauer Plasselb wechselschichtig', 'Natursteinmauer geschichtet in Blöcken');
  if ids is null or array_length(ids, 1) <> 9 then raise exception 'Erwartet 9 Optionen, gefunden %', coalesce(array_length(ids, 1), 0); end if;

  verw := jsonb_build_array(jsonb_build_object('eingabefeld_id', ef, 'spalte_id', sp_fl, 'gruppe', 'mauer'));
  update auswahloption set tabellenverweis = verw, mehrfachauswahl = true, mengenoption = false where id = any(ids);

  -- Menge je m²: "Sichtfläche * x" -> "x"; Stein: Gewicht -> Tonnen je m²
  update ressourcenzeile rz set menge_ausdruck = rz.menge_ausdruck->'args'->1
   where rz.option_id = any(ids) and rz.menge_ausdruck->>'op' = '*' and rz.menge_ausdruck->'args'->0->>'id' = t_fl::text;
  get diagnostics n = row_count;
  update ressourcenzeile rz set menge_ausdruck = jsonb_build_object('id', t_tpm, 'ref', 'term')
   where rz.option_id = any(ids) and rz.artikel_id in (a_w, a_s);
  if exists (select 1 from ressourcenzeile where option_id = any(ids) and menge_ausdruck::text like '%' || t_fl::text || '%') then raise exception 'Es sind noch Sichtfläche-Formeln uebrig'; end if;
  raise notice 'Zeilen auf je m2 umgestellt: %', n;
end $$;
