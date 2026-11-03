-- Bauprogramm gehört zu einem Planer-Balken (Baustelle des Vorarbeiters), nicht mehr fest zum Kunden.
-- Ein Kunde kann mehrere Programme haben (verschiedene Projekte über die Jahre).
-- ab_ids = ausgewählte Auftragsbestätigungen (easybill_dokument.easybill_id) dieses Kunden.

alter table bauprogramm add column if not exists einsatz_id uuid references planer_einsatz(id) on delete set null;
alter table bauprogramm add column if not exists ab_ids bigint[] not null default '{}';

drop index if exists bauprogramm_kunde;
create index if not exists bauprogramm_kunde_idx on bauprogramm (kunde_id);
create unique index if not exists bauprogramm_einsatz on bauprogramm (einsatz_id) where einsatz_id is not null;

-- Bestehende Programme: an den Baustellen-Balken des Kunden hängen (der längste, falls mehrere),
-- ABs = alle Auftragsbestätigungen dieses Kunden (wie bisher)
update bauprogramm p set einsatz_id = (
    select e.id from planer_einsatz e
    where e.kunde_id = p.kunde_id and e.art = 'baustelle'
    order by (e.ende - e.beginn) desc nulls last limit 1)
where p.einsatz_id is null;

update bauprogramm p set ab_ids = coalesce((
    select array_agg(d.easybill_id order by d.datum desc) from easybill_dokument d
    where d.kunde_id = p.kunde_id and d.typ = 'ORDER'), '{}')
where p.ab_ids = '{}';
