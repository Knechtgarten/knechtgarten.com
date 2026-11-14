-- Neue Ansicht Tool A: Zeilen als «optional» markieren (im Dokument sichtbar, zählt nicht zum Total, nicht im Easybill-Export).
alter table public.offerte_zeilen_korrektur add column if not exists optional boolean not null default false;
alter table public.offerte_eigene_zeile add column if not exists optional boolean not null default false;
