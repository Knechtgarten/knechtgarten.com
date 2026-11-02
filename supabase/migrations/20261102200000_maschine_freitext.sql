-- Planer «Diverse Maschinen»: freier Text statt bestimmter Maschine (z. B. «Rüttelplatte», «Mietbagger»),
-- gilt für eine Baustelle bzw. einen Termin, ohne Schloss und ohne Konfliktprüfung.
alter table planer_ressource_einsatz add column if not exists freitext text;
alter table planer_ressource_einsatz drop constraint if exists planer_ressource_einsatz_ziel;
alter table planer_ressource_einsatz add constraint planer_ressource_einsatz_ziel check (
  ressource_id is not null
  or (typ_eintrag_id is not null and einsatz_id is not null)
  or (nullif(btrim(freitext), '') is not null and einsatz_id is not null)
);
