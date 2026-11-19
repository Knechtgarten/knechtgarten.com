-- Projektleiter / Büroteam darf Adressen (Kunden) löschen – in Offerten und Pflege.
-- Kunden mit Offerten oder Pflegeauftrag bleiben durch die Datenbank geschützt (Fremdschlüssel «restrict»).
update recht_eintrag e set wert = 'A'
from recht_gruppe g
where e.gruppe_id = g.id and g.name = 'Projektleiter / Büroteam'
  and e.tool_key in ('offerten', 'pflege') and e.bereich_key = 'kunden' and e.aktion = 'loeschen';

select e.tool_key, e.wert from recht_eintrag e join recht_gruppe g on g.id = e.gruppe_id
where g.name = 'Projektleiter / Büroteam' and e.bereich_key = 'kunden' and e.aktion = 'loeschen';
