-- ============================================================================
-- Offertentool 2027 - Terms (Formel-Bibliothek) per Drag&Drop sortierbar
-- machen, gleiches Muster wie zuvor bei eingabefeld.reihenfolge.
-- ============================================================================

alter table term add column reihenfolge integer not null default 0;

-- Bestehende Eintraege bekommen eine sinnvolle Startreihenfolge (nach Name,
-- getrennt je Offertentyp/Allgemein) - danach frei per Drag&Drop aenderbar.
update term t
set reihenfolge = sub.rn
from (
  select id, row_number() over (
    partition by offertentyp_id order by name
  ) as rn
  from term
) sub
where t.id = sub.id;
