-- Pendenzen: eigene Farbe pro Person (unabhängig vom Einsatzplaner). In gemeinsamen Boards wird jede Pendenz
-- hell in der Farbe der Person hinterlegt, die sie eingetragen hat. Startwerte wie im Trello.
create table pendenz_person_farbe (
  benutzer_id uuid primary key references benutzer(id) on delete cascade on update cascade,
  farbe text not null
);
alter table pendenz_person_farbe enable row level security;
create policy pendenz_person_farbe_voll on pendenz_person_farbe for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

insert into pendenz_person_farbe (benutzer_id, farbe)
select u.id, v.farbe from (values
  ('mail@knechtgarten.ch', '#579DFF'),
  ('fabian.oberholzer@knechtgarten.ch', '#FEA362'),
  ('bau@knechtgarten.ch', '#F5CD47'),
  ('pascal.wuethrich@knechtgarten.ch', '#4BCE97')
) as v(email, farbe) join benutzer u on u.email = v.email
on conflict (benutzer_id) do update set farbe = excluded.farbe;
