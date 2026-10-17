-- ============================================================================
-- Bewaesserungsplan: Intervall als freier Text (z. B. «Mo, Mi, Fr, So (Di, Do, Sa 10 %)»)
-- und «Reagiert mit Sensor» (Ja/Nein) wird «Sensor» mit Sensorbezeichnung aus Rohnertec.
-- ============================================================================
update pflege_tabelle_spalte s set typ = 'text', optionen = '[]'::jsonb
  from pflege_tabelle t join pflege_kategorie k on k.id = t.kategorie_id
 where s.tabelle_id = t.id and k.name = 'Bewässerung' and s.name = 'Intervall';
update pflege_tabelle_spalte s set typ = 'text', name = 'Sensor', optionen = '[]'::jsonb
  from pflege_tabelle t join pflege_kategorie k on k.id = t.kategorie_id
 where s.tabelle_id = t.id and k.name = 'Bewässerung' and s.name = 'Reagiert mit Sensor';
