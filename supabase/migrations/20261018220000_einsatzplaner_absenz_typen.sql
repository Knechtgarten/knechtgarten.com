-- Einsatzplaner: Absenz-Typen mit Grauton (0 = hell … 5 = dunkel), optional gestreift.
-- Eine Absenz speichert ihren Typ im Titel (planer_einsatz.titel), der Planer färbt danach.
create table planer_absenz_typ (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  grauton int not null default 1 check (grauton between 0 and 5),
  gestreift boolean not null default false,
  sortierung int not null default 0
);
alter table planer_absenz_typ enable row level security;
create policy planer_absenz_typ_lesen on planer_absenz_typ for select using (ist_eingeloggter_benutzer());
create policy planer_absenz_typ_buero on planer_absenz_typ for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
alter publication supabase_realtime add table planer_absenz_typ;
insert into planer_absenz_typ (name, grauton, gestreift, sortierung) values
  ('Ferien', 1, false, 10), ('Krank', 3, false, 20), ('Unfall', 3, true, 30),
  ('Frei', 0, false, 40), ('Schule', 2, false, 50), ('Militär', 5, false, 60);
