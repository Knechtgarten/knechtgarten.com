-- Büro (Recht «Offertentool › Vorlagen bearbeiten») darf in «Vorlagen & Berechnung» fast alles anpassen:
-- Vorlagen, Preise, Vorauswahlen, Berechnungsregeln, bestehende Formeln und Eingabefelder ändern.
-- Nur mit Schalter «Sonderpositionen & neue Formeln/Felder» (sonst nur Admin): Sonderpositionen, Eingabefelder und Formeln anlegen oder löschen.
create or replace function public.darf_vorlagen() returns boolean language sql stable security definer set search_path to 'public' as $$
  select ist_admin() or recht_darf('offerten', 'vorlagen', 'bearbeiten');
$$;
create or replace function public.darf_berechnung() returns boolean language sql stable security definer set search_path to 'public' as $$
  select ist_admin() or coalesce(recht_wert('offerten', 'einstellungen', 'an'), 'N') = 'J';
$$;

do $$ declare t text; begin
  foreach t in array array['offertentyp','vorauswahl','vorauswahl_option','offerten_position_einstellung','lieferwagen_konfiguration','option_freitext_vorlage','preisabgleich_warnstufen'] loop
    execute format('drop policy if exists %I on %I', t || '_admin_schreibt', t);
    execute format('drop policy if exists %I on %I', t || '_vorlagen_schreibt', t);
    execute format('create policy %I on %I for all to authenticated using (darf_vorlagen()) with check (darf_vorlagen())', t || '_vorlagen_schreibt', t);
  end loop;
  foreach t in array array['sonderposition_typ','staffelgruppe','staffelstufe','auswahlgruppe','auswahlgruppe_option','transport_werk','transport_preis','transport_distanzstufe','zonengruppe'] loop
    execute format('drop policy if exists %I on %I', t || '_admin_schreibt', t);
    execute format('drop policy if exists %I on %I', t || '_berechnung_schreibt', t);
    execute format('create policy %I on %I for all to authenticated using (darf_berechnung()) with check (darf_berechnung())', t || '_berechnung_schreibt', t);
  end loop;
  -- Formeln und Eingabefelder: ändern mit «Vorlagen», anlegen/löschen nur mit «Sonderpositionen & neue Formeln/Felder»
  foreach t in array array['term','eingabefeld'] loop
    execute format('drop policy if exists %I on %I', t || '_admin_schreibt', t);
    execute format('drop policy if exists %I on %I', t || '_aendern', t);
    execute format('drop policy if exists %I on %I', t || '_anlegen', t);
    execute format('drop policy if exists %I on %I', t || '_loeschen', t);
    execute format('create policy %I on %I for update to authenticated using (darf_vorlagen()) with check (darf_vorlagen())', t || '_aendern', t);
    execute format('create policy %I on %I for insert to authenticated with check (darf_berechnung())', t || '_anlegen', t);
    execute format('create policy %I on %I for delete to authenticated using (darf_berechnung())', t || '_loeschen', t);
  end loop;
end $$;
-- Wechselkurse (Preise): mit «Vorlagen»
drop policy if exists wechselkurs_admin on wechselkurs;
drop policy if exists wechselkurs_vorlagen_schreibt on wechselkurs;
create policy wechselkurs_vorlagen_schreibt on wechselkurs for all to authenticated using (darf_vorlagen()) with check (darf_vorlagen());

-- Anlegen von Formeln/Eingabefeldern auch mit «Vorlagen» (Vorlage kopieren «mit Formel-Vorlagen»);
-- die Knöpfe «Neuer Wert» / «Eingabefeld hinzufügen» zeigt die Oberfläche trotzdem nur mit «Sonderpositionen & neue Formeln/Felder». Löschen bleibt dort.
drop policy if exists term_anlegen on term;
create policy term_anlegen on term for insert to authenticated with check (darf_vorlagen());
drop policy if exists eingabefeld_anlegen on eingabefeld;
create policy eingabefeld_anlegen on eingabefeld for insert to authenticated with check (darf_vorlagen());
