-- ============================================================================
-- Einsatzplaner: Sonderzeile «Allgemein → Service» für die Service-Arbeiten aus
-- «Wissen & Geräte» (wissen_service mit im_planer). Geräte mit Planer-Verknüpfung
-- zeigen ihren Service zusätzlich auf der eigenen Zeile (Maschinen/Fahrzeuge/Anhänger).
-- Abhaken im Planer schreibt in wissen_service_erledigt (gleicher Haken wie im Wissens-Tool).
-- ============================================================================
insert into planer_person (gruppe_id, name, sortierung)
select g.id, 'Service', coalesce((select max(p.sortierung) from planer_person p where p.gruppe_id = g.id), 0) + 10
from planer_gruppe g
where g.name = 'Allgemein'
  and not exists (select 1 from planer_person p where p.gruppe_id = g.id and lower(p.name) = 'service');
