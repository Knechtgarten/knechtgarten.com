-- ============================================================================
-- Nachschlagewerk Etappe 5: Kurzinfo – Einträge ohne Detailseite, der Wert steht direkt in Liste und Suche.
-- wert = die Angabe selbst (z. B. MWST-Nummer), untertitel dient als kurzer Hinweis.
-- Neue Kategorie «Firma & Administration» in der Rubrik Kurzinfo.
-- ============================================================================
alter table wissen_eintrag add column if not exists wert text;

insert into wissen_kategorie (name, sortierung, art, bausteine, mit_service)
select 'Firma & Administration', coalesce(max(sortierung), 0) + 10, 'kurz', '[]'::jsonb, false from wissen_kategorie
where not exists (select 1 from wissen_kategorie where name = 'Firma & Administration');
