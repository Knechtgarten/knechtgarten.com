-- Projektleiter / Büroteam: Artikel auch löschen dürfen (ansehen, bearbeiten, erfassen hatten sie schon) – Stefan, 18.11.2026
-- Gleiche Einstellung wie in Einstellungen › Gruppen & Rechte › Offertentool › Artikel › Löschen = Alle
update public.recht_eintrag e set wert = 'A'
from public.recht_gruppe g
where g.id = e.gruppe_id and g.name = 'Projektleiter / Büroteam' and e.tool_key = 'offerten' and e.bereich_key = 'artikel' and e.aktion = 'loeschen'
returning g.name, e.aktion, e.wert;
