-- ============================================================================
-- Pendenzen: Besprechen in die Mitte, Verknuepfung zum Einsatzplaner, Buero-Board
-- ============================================================================

-- Besprechen ist eine Pendenzenart (Mitte), rechts bleibt nur die Team-box
update pendenz_liste set bereich = 'mitte', x = 20, y = 2000 where art_id = 'besprechen' and bereich = 'team';

-- Pendenz -> offener Auftrag im Einsatzplaner (Pendenz bleibt, zeigt das Planer-Zeichen)
alter table pendenz add column if not exists planer_einsatz_id uuid null references planer_einsatz(id) on delete set null;

-- Gemeinsames Buero-Board (ohne Zeit-Bereich) mit Mitgliedern Stefan, Benu, Fabian, Pascal
with b as (
  insert into pendenz_board (name, typ, mail_kuerzel) values ('Büro-Board', 'gemeinsam', 'buero') returning id
), m as (
  insert into pendenz_board_mitglied (board_id, benutzer_id)
  select b.id, u.id from b, benutzer u
  where u.email in ('mail@knechtgarten.ch', 'bau@knechtgarten.ch', 'fabian.oberholzer@knechtgarten.ch', 'pascal.wuethrich@knechtgarten.ch')
  returning 1
)
insert into pendenz_liste (board_id, art_id, titel, bereich, x, y)
select b.id, v.art_id, v.titel, v.bereich, v.x, v.y from b, (values
  ('besprechen', 'Zum besprechen',        'mitte', 20,  20),
  ('avor',       'Planung',               'mitte', 360, 20),
  ('admin',      'Langfristig',           'mitte', 700, 20),
  ('besprechen', 'Sitzungsthemen',        'mitte', 20,  300),
  ('personal',   'Infos an Mitarbeiter',  'mitte', 360, 300),
  ('team',       'Team-box',              'team',  20,  20)
) as v(art_id, titel, bereich, x, y);
