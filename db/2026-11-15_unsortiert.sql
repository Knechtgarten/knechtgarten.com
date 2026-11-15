-- Kachel «Unsortiert» im eigenen Board: hier wohnen Pendenzen, die im Rad («Pendenz terminieren») erfasst wurden,
-- und Pendenzen ohne eigenen Platz, die man zurück in die Mitte zieht. Leer = ausgeblendet (macht das Tool).
insert into public.pendenz_art (id, titel, icon, farbe, funktion, aktiv, sortierung)
values ('unsortiert', 'Unsortiert', 'ebenen', '#8B9097', true, true, 125)
on conflict (id) do nothing;
select id, titel from public.pendenz_art where id = 'unsortiert';
