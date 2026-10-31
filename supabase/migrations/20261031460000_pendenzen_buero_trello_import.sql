-- Büro-Board: Karten aus Trello «Bürositzung» übernehmen (Titel wie in Trello, ohne Labels/Zeit)
with b as (select id from pendenz_board where typ = 'gemeinsam' and mail_kuerzel = 'buero'),
ich as (select id from benutzer where email = 'mail@knechtgarten.ch'),
v(liste, titel, nr) as (values
  ('Zum besprechen', 'Text Blaze verwenden?', 1),
  ('Zum besprechen', 'Wie machen wir am Besten die Pflanzenbestellungen? Planungen?', 2),
  ('Zum besprechen', 'Dienstag, 23.03.2027 BAM Steffisburg', 3),
  ('Zum besprechen', 'Anschaffung RK057 (35''600.– minus 10%)', 4),
  ('Zum besprechen', 'Was für ein Praxisthema bei der nächsten Mitarbeitersitzung? (30. November)', 5),
  ('Zum besprechen', 'Beispiel Anwendung Claude', 6),
  ('Zum besprechen', 'Stand Knecht Tool', 7),
  ('Zum besprechen', 'Welche Weihnachtsgeschenke für Kunden?', 8),
  ('Zum besprechen', 'Stundenansatz im Januar für 27 definieren', 9),
  ('Zum besprechen', 'Löhne Mitarbeitende / Mitarbeitergespräche', 10),
  ('Zum besprechen', 'Auftragsbestätigungen senden', 11),
  ('Planung', 'Lea Maccorone «Grabstein»', 1),
  ('Planung', 'Balmer Steffisburg 1 Woche', 2),
  ('Langfristig', 'Notfalltelefon Handling', 1),
  ('Langfristig', 'Bei grossen Projekten nur noch 5% Abweichung in Text schreiben? Oder Personal und Budgetposten 10%', 2),
  ('Langfristig', 'Kehrmaschine für Magazin – Flächen einfacher sauber halten', 3),
  ('Langfristig', 'Guter Text zum Nachhaken', 4),
  ('Langfristig', 'Trachsel Wattenwil Technikumbau: Reinigung Ersatztermin 27. August → keine Offerte, sondern per Mail', 5),
  ('Infos an Mitarbeiter', 'Offerte Müller', 1)
)
insert into pendenz (liste_id, titel, sortierung, erstellt_von)
select l.id, v.titel, v.nr, (select id from ich)
from v join pendenz_liste l on l.titel = v.liste and l.board_id = (select id from b);
