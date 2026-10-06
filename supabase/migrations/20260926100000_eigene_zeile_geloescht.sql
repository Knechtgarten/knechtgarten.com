-- Von Hand geloeschte Freitext-Position (aus einer Vorlage) bleibt als
-- unsichtbare Markierung stehen, damit Tool A sie nicht beim naechsten
-- Neuberechnen sofort wieder anlegt (seedeFreitextZeilen).
alter table offerte_eigene_zeile add column geloescht boolean not null default false;
