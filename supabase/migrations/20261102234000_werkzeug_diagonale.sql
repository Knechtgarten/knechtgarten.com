-- Werkzeuge: Rechner «Rechter Winkel» (Diagonale), Schalter für alle Gruppen «Ja»
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'werkzeuge', 'bau_diagonale', 'an', 'J' from recht_gruppe g
on conflict do nothing;
