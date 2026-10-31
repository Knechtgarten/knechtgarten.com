-- Büro-Board: Ersteller der Trello-Karten nach Trello-Labels (blau Stefan, orange Fabian, gelb Benno, grün Pascal; ohne Label = Stefan)
update pendenz p set erstellt_von = u.id
from (values
  ('Was für ein Praxisthema bei der nächsten Mitarbeitersitzung? (30. November)', 'bau@knechtgarten.ch'),
  ('Bei grossen Projekten nur noch 5% Abweichung in Text schreiben? Oder Personal und Budgetposten 10%', 'bau@knechtgarten.ch'),
  ('Stundenansatz im Januar für 27 definieren', 'fabian.oberholzer@knechtgarten.ch'),
  ('Löhne Mitarbeitende / Mitarbeitergespräche', 'fabian.oberholzer@knechtgarten.ch'),
  ('Kehrmaschine für Magazin – Flächen einfacher sauber halten', 'fabian.oberholzer@knechtgarten.ch'),
  ('Trachsel Wattenwil Technikumbau: Reinigung Ersatztermin 27. August → keine Offerte, sondern per Mail', 'fabian.oberholzer@knechtgarten.ch'),
  ('Balmer Steffisburg 1 Woche', 'pascal.wuethrich@knechtgarten.ch')
) as v(titel, email)
join benutzer u on u.email = v.email
where p.titel = v.titel
  and p.liste_id in (select l.id from pendenz_liste l join pendenz_board b on b.id = l.board_id where b.mail_kuerzel = 'buero');
