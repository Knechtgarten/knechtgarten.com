-- ============================================================================
-- Einsatzplaner: Startbestand Personen (aus Tom's Planner, Stand 2026-10-18)
--
-- Jede Person bekommt einen Benutzer OHNE Login (ist_platzhalter, wie im
-- Pflege-Tool «Person ohne Login») und eine Zeile im Planer, verknuepft ueber
-- planer_person.benutzer_id. Meldet sich jemand spaeter mit Login an, verknuepft
-- der Admin die E-Mail in der Benutzerverwaltung – die Zeile bleibt dieselbe.
-- Marco (service@knechtgarten.ch) und Samir gibt es schon: werden nur verknuepft.
-- Gruppen wie in Tom's Planner benannt, oben Gruppe «Allgemein» mit Sonderzeilen.
-- ============================================================================

update planer_gruppe set name = 'Gartenpflege' where name = 'Gartenpflege / Service';
update planer_gruppe set name = 'Pool – Wasser – Bewässerung' where name = 'Pool / Wasser';
update planer_gruppe set name = 'Lehrlinge / Mitarbeitende' where name = 'Lernende / Mitarbeitende';
insert into planer_gruppe (name, sortierung)
select 'Allgemein', 0 where not exists (select 1 from planer_gruppe where name = 'Allgemein');

do $$
declare
  r record;
  bid uuid;
  gid uuid;
  i int := 0;
  pal text[] := array['#3E6B4F','#5B8C6A','#7FA88A','#2F6F6B','#4F8F8A','#86B3AE','#56707F','#6E8F4E','#9DB27C','#2F4F5F','#7D8B5A','#4A6C8C'];
begin
  for r in
    select * from (values
      ('Gartenpflege', 'Cornelia Hirschi', 'service_team', true, null::text, 10),
      ('Gartenpflege', 'Selina Durrer', 'service_team', true, null, 20),
      ('Gartenpflege', 'Samir Akhdar', 'service_team', true, 'akhdarsamir@gmail.com', 30),
      ('Gartenpflege', 'Andrea Hadorn', 'service_team', true, null, 40),
      ('Lehrlinge / Mitarbeitende', 'Raphael Walther', 'mitarbeitende', false, null, 10),
      ('Lehrlinge / Mitarbeitende', 'Sandra Rufener', 'mitarbeitende', false, null, 20),
      ('Lehrlinge / Mitarbeitende', 'Dian Baumann', 'mitarbeitende', false, null, 30),
      ('Lehrlinge / Mitarbeitende', 'Tamino Zaugg', 'mitarbeitende', false, null, 40),
      ('Lehrlinge / Mitarbeitende', 'Gonzalo Rodea', 'mitarbeitende', false, null, 50),
      ('Lehrlinge / Mitarbeitende', 'Tim Bürki', 'mitarbeitende', false, null, 60),
      ('Lehrlinge / Mitarbeitende', 'Nick Gersbach', 'mitarbeitende', false, null, 70),
      ('Pool – Wasser – Bewässerung', 'Marco Gfeller', 'service_team', true, 'service@knechtgarten.ch', 10),
      ('Equipe Gartenbau', 'Dominic Glur', 'mitarbeitende', false, null, 10),
      ('Equipe Gartenbau', 'Remo Reusser', 'mitarbeitende', false, null, 20),
      ('Equipe Gartenbau', 'Timo Jost', 'mitarbeitende', false, null, 30),
      ('Equipe Gartenbau', 'Stefanie Röthlisberger', 'mitarbeitende', false, null, 40),
      ('Equipe Gartenbau', 'Kai Abgottspon', 'mitarbeitende', false, null, 50),
      ('Equipe Gartenbau', 'Fabian Reusser', 'mitarbeitende', false, null, 60)
    ) as t(gruppe, name, rolle, pflege, email, sort)
  loop
    i := i + 1;
    select id into gid from planer_gruppe where name = r.gruppe;
    if exists (select 1 from planer_person where name = r.name) then continue; end if;
    -- bestehenden Benutzer nehmen (gleiche E-Mail oder gleicher Anzeigename), sonst neu ohne Login
    select id into bid from benutzer
     where (r.email is not null and lower(email) = lower(r.email)) or lower(anzeigename) = lower(r.name)
     limit 1;
    if bid is null then
      bid := gen_random_uuid();
      insert into benutzer (id, email, anzeigename, rolle, aktiv, pflege_zustaendig, ist_platzhalter)
      values (bid, null, r.name, r.rolle, true, r.pflege, true);
    end if;
    insert into planer_person (name, gruppe_id, farbe, benutzer_id, sortierung)
    values (r.name, gid, pal[1 + (i - 1) % 12], bid, r.sort);
  end loop;
end $$;

-- Sonderzeilen oben (ohne Benutzer)
insert into planer_person (name, gruppe_id, farbe, sortierung)
select v.name, g.id, '#8B9097', v.sort
from (values ('Termine', 10), ('Kurse / Weiterbildung', 20), ('Liefertermine', 30)) v(name, sort)
cross join planer_gruppe g
where g.name = 'Allgemein' and not exists (select 1 from planer_person p where p.name = v.name);
