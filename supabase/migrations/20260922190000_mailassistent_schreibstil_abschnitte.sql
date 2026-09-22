-- ============================================================================
-- Mail-Assistent: Schreibstil-Inhalt von einem einzelnen Textfeld auf frei
-- benannte, einzeln hinzufuegbare/loeschbare Abschnitte umgestellt (gleiches
-- Muster wie Grundlogik/Faelle). Die "Immer bei Verfassen/Antworten"-
-- Checkboxen bleiben bewusst an der bestehenden mailassistent_schreibstil-
-- Tabelle (nur diese zwei Spalten werden dort noch genutzt).
--
-- Der bisherige Freitext wird 1:1 per SQL aus der LIVE-Tabelle uebernommen
-- (nicht von Claude abgetippt) - dadurch bleibt der aktuelle Inhalt exakt
-- erhalten, unabhaengig davon was genau drinsteht. Landet zunaechst als EIN
-- grosser Abschnitt "Schreibstil (bestehend)" - kann danach in mehrere
-- kleinere Abschnitte mit eigenen Titeln aufgeteilt werden.
-- ============================================================================

create table if not exists mailassistent_schreibstil_abschnitt (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  inhalt text,
  reihenfolge integer not null default 0
);

insert into mailassistent_schreibstil_abschnitt (titel, inhalt, reihenfolge)
select 'Schreibstil (bestehend)', inhalt, 0
from mailassistent_schreibstil
where not exists (select 1 from mailassistent_schreibstil_abschnitt)
limit 1;
