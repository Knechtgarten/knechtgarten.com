-- ============================================================================
-- Offertentool 2027 - Eingabefelder (Formel-Bibliothek) per Drag&Drop
-- sortierbar machen, statt fixer alphabetischer/Einfuege-Reihenfolge.
-- ============================================================================

alter table eingabefeld add column reihenfolge integer not null default 0;

-- Bestehende Eintraege bekommen eine sinnvolle Startreihenfolge (nach Name,
-- getrennt je Offertentyp/Allgemein) - danach frei per Drag&Drop aenderbar.
update eingabefeld ef
set reihenfolge = sub.rn
from (
  select id, row_number() over (
    partition by offertentyp_id order by name
  ) as rn
  from eingabefeld
) sub
where ef.id = sub.id;
