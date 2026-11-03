-- Bauprogramm mit Lappen: Blöcke gehören zu einer Gruppe (Angebot oder herausgelöster Block).
-- gruppe = Kennung der Gruppe (vom Client vergeben), angebot = Schlüssel des Angebots (z. B. 'of:<offerte_id>' / 'eb:<easybill_id>'),
-- los = herausgelöst (eigener Block, gestreifter Lappen «aus …»). Ein Block = ein Arbeitsschritt oder ein Stück davon.
alter table public.bauprogramm_block add column if not exists gruppe text;
alter table public.bauprogramm_block add column if not exists angebot text;
alter table public.bauprogramm_block add column if not exists los boolean not null default false;
