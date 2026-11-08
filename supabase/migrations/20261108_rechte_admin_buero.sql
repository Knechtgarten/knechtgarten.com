-- Rechte bereinigt (kg-rechte.js): Administrator = nur Stefan; Benu, Pascal, Fabian → Projektleiter / Büroteam; Marco → Poolservice.
-- Büroteam: Offerten-Vorlagen ja, «Berechnung & Einstellungen» nein; Listen in gemeinsamen Boards nur Admin; endgültig löschen in gemeinsamen Boards nur eigene.
update benutzer set recht_gruppe_id = (select id from recht_gruppe where name = 'Projektleiter / Büroteam')
 where id in ('033a207f-7834-433c-9369-3a09ebff58f5', '93790c9c-35ea-4943-afc8-a6f245d5c2af', '6b59611a-6065-4578-b12a-204923545e39');
update benutzer set recht_gruppe_id = (select id from recht_gruppe where name = 'Poolservice') where id = '54ebd42b-47ec-4dc7-aee1-21e728b1a6a9';
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, v.t, v.b, v.a, v.w from recht_gruppe g, (values ('offerten', 'einstellungen', 'an', 'N'), ('pend', 'listen', 'an', 'N'), ('pend', 'gemeinsam', 'loeschen', 'E')) v(t, b, a, w)
where g.name = 'Projektleiter / Büroteam'
on conflict (gruppe_id, tool_key, bereich_key, aktion) do update set wert = excluded.wert;
-- Gemeinsame Boards für alle anderen Gruppen: Listen verwalten aus, endgültig löschen nur eigene
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, v.t, v.b, v.a, v.w from recht_gruppe g, (values ('pend', 'listen', 'an', 'N'), ('pend', 'gemeinsam', 'loeschen', 'E')) v(t, b, a, w)
where not g.ist_admin and g.name <> 'Projektleiter / Büroteam'
on conflict (gruppe_id, tool_key, bereich_key, aktion) do nothing;
