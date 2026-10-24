-- ============================================================================
-- Nachschlagewerk Etappe 4: Bausteine «Mehrfach ohne Service» (k = mehrfach) und «Mehrfach mit Service» (k = mehrfachS).
-- Ersetzen die Exemplar-Teile (x_angaben, x_service, x_notizen) und den Abschnitt «Service-Arbeiten» (service).
-- Geräte-Kategorien bekommen «Mehrfach mit Service» an der Stelle des ersten Exemplar-Teils, die übrigen keinen.
-- mit_service der Kategorie = hat «Mehrfach mit Service» (liest der Einsatzplaner).
-- ============================================================================
do $$
declare k record; b jsonb; neu jsonb; drin boolean;
begin
  for k in select id, art, bausteine from wissen_kategorie where bausteine is not null loop
    neu := '[]'::jsonb; drin := false;
    for b in select * from jsonb_array_elements(k.bausteine) loop
      if b->>'k' like 'x\_%' or b->>'k' = 'service' then
        if not drin and k.art = 'geraet' then neu := neu || jsonb_build_array(jsonb_build_object('k', 'mehrfachS', 'm', 'offen')); drin := true; end if;
      elsif b->>'k' not in ('mehrfach', 'mehrfachS') then
        neu := neu || jsonb_build_array(b);
      end if;
    end loop;
    update wissen_kategorie set bausteine = neu, mit_service = drin where id = k.id;
  end loop;
end $$;
