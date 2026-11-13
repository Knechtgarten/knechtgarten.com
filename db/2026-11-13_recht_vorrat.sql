-- Neues Recht «Einsatzplaner › Vorrat bearbeiten»: Büro-Gruppen bekommen «Alle», alle anderen bleiben ohne Eintrag (= Keine)
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select id, 'plan', 'vorrat', 'bearbeiten', 'A' from recht_gruppe where bereich = 'buero' and not ist_admin
on conflict do nothing;
