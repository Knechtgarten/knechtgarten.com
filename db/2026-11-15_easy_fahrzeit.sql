-- Easy: Fahrzeit pro Zeile (Personal + Fahrzeug). menge_basis = Menge ohne Fahrzeit, Fahrzeit wird automatisch dazugerechnet.
alter table public.easy_vorlage_zeile add column if not exists fahrt boolean not null default false;
alter table public.offerte_eigene_zeile add column if not exists menge_basis numeric;
alter table public.offerte_eigene_zeile add column if not exists fahrt boolean not null default false;
alter table public.offerte_eigene_zeile add column if not exists fahrt_manuell boolean not null default false;

-- Kipper doppelt (Std + Budget): Einheit ist umschaltbar, eine Zeile reicht
delete from public.easy_vorlage_zeile b
 where b.einheit = 'Budget' and b.bezeichnung like 'Transportaufwand%'
   and exists (select 1 from public.easy_vorlage_zeile s where s.vorlage_id = b.vorlage_id and s.bezeichnung = b.bezeichnung and s.einheit ilike 'Std%');

-- Fahrzeit: Personal (ohne Projektleiter/Fachplanung) und das erste Fahrzeug pro Vorlage
update public.easy_vorlage_zeile set fahrt = true
 where kategorie = 'personal' and bezeichnung !~* '(projektleiter|fachplanung)';
update public.easy_vorlage_zeile z set fahrt = true
 where z.id in (select distinct on (vorlage_id) id from public.easy_vorlage_zeile
                 where bezeichnung ~* '^(lieferwagen|transportaufwand)' and einheit ilike 'std%' order by vorlage_id, reihenfolge);
