-- Mail-Assistent: das Backend liest den Schreibstil neu aus
-- mailassistent_schreibstil_abschnitt (das, was im Admin-Tool unter
-- "Schreibstil" sichtbar/editierbar ist), nicht mehr aus der alten
-- Einzelspalte mailassistent_schreibstil.inhalt (die im Tool seit der
-- Umstellung auf Abschnitte gar nicht mehr angezeigt/editiert wurde - beide
-- Inhalte liefen seither auseinander). Falls dort noch Text steht und die
-- Abschnitte-Liste leer ist, hier 1:1 als ersten Abschnitt uebernehmen,
-- damit nichts verloren geht.
insert into mailassistent_schreibstil_abschnitt (titel, inhalt, reihenfolge)
select 'Schreibstil (migriert)', inhalt, 0
from mailassistent_schreibstil
where inhalt is not null and trim(inhalt) <> ''
  and not exists (select 1 from mailassistent_schreibstil_abschnitt)
limit 1;
