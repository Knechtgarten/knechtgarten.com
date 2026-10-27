-- ============================================================================
-- Einsatzplaner: Maschinen-Typ vorläufig reservieren, einzelne Maschine fest
--
-- Typ = Eintrag im Nachschlagewerk (wissen_eintrag), z. B. «Raupenbagger 3.5 t»,
-- seine Stück (wissen_exemplar.planer_ressource_id) sind die Maschinen.
-- Vorläufig (Häkchen) = typ_eintrag_id gesetzt, ressource_id leer.
-- Fest (Schloss)      = ressource_id gesetzt (bestimmte Maschine).
-- ============================================================================
alter table planer_ressource_einsatz add column if not exists typ_eintrag_id uuid null references wissen_eintrag(id) on delete cascade;
alter table planer_ressource_einsatz alter column ressource_id drop not null;
alter table planer_ressource_einsatz drop constraint if exists planer_ressource_einsatz_ziel;
alter table planer_ressource_einsatz add constraint planer_ressource_einsatz_ziel
  check (ressource_id is not null or (typ_eintrag_id is not null and einsatz_id is not null));

-- Bisherige vorläufige Maschinen-Reservierungen werden Typ-Reservierungen
update planer_ressource_einsatz pe set typ_eintrag_id = x.eintrag_id, ressource_id = null
  from planer_ressource r join wissen_exemplar x on x.planer_ressource_id = r.id
  where r.id = pe.ressource_id and r.typ = 'maschine' and not pe.fest;
