-- ============================================================================
-- Einsatzplaner: «Wichtige Info» im Termin wird wieder ein freies Icon bei der Person (planer_markierung, art 'info').
-- Bestehende Infos aus planer_einsatz_info übernehmen (Person des Termins, ganzer Tag, gleicher Text), dann löschen.
-- ============================================================================
insert into planer_markierung (person_id, tag, teil, art, text, erstellt_von)
select e.person_id, i.tag, 'ganz', 'info', i.text, i.erstellt_von
from planer_einsatz_info i join planer_einsatz e on e.id = i.einsatz_id
where not exists (select 1 from planer_markierung m where m.person_id = e.person_id and m.tag = i.tag and m.art = 'info');

delete from planer_einsatz_info;
