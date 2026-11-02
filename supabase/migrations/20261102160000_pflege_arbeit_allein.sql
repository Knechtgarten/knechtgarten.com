-- ============================================================================
-- Pflege-Tool: Arbeit «Allein» ausführbar (pro Kunde und Arbeit). Der Termin im Einsatzplaner übernimmt das
-- beim Abmachen (allein = true): blauer Strich statt rot «Personal fehlt».
-- ============================================================================
alter table pflege_kunde_arbeit add column if not exists allein boolean not null default false;
