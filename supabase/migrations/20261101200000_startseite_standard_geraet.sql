-- Startseiten-Standard pro Gruppe getrennt für Desktop und Handy
alter table startseite_standard add column if not exists geraet text not null default 'desktop' check (geraet in ('desktop', 'handy'));
alter table startseite_standard drop constraint if exists startseite_standard_pkey;
alter table startseite_standard add primary key (recht_gruppe_id, geraet);
