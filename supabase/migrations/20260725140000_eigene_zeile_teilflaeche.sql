-- ============================================================================
-- Offertentool 2027 - "Eigene Position" (offerte_eigene_zeile) bekommt eine
-- optionale Teilflaechen-Zuordnung.
--
-- Grund: Die Kostenaufstellung in Tool A wird pro Teilflaeche eingebettet
-- (eigene Zwischentotale statt einer einzigen offertenweiten Tabelle) - eine
-- manuell hinzugefuegte "Eigene Position" muss deshalb einer bestimmten
-- Teilflaeche zugeordnet werden koennen. Bleibt nullable, da Tagessatz-
-- Offerten (Tool A2) kein Teilflaechen-Konzept kennen, aber dasselbe
-- offerte_eigene_zeile-Muster weiterverwenden.
-- ============================================================================

alter table offerte_eigene_zeile add column teilflaeche_id uuid null references teilflaeche(id) on delete cascade;

-- Bestehende (bisher offertenweite) Eigene Positionen best effort der ersten
-- Teilflaeche jeder Offerte zuordnen (nur Testdaten betroffen).
update offerte_eigene_zeile ez
set teilflaeche_id = (
  select t.id from teilflaeche t where t.offerte_id = ez.offerte_id order by t.reihenfolge limit 1
)
where teilflaeche_id is null;
