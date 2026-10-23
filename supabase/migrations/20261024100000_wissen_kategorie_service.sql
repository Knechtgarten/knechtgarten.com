-- ============================================================================
-- Wissen & Geräte: «Service & Wartung verwenden» pro Kategorie. Aus = bei Einträgen
-- dieser Kategorie (und im Einsatzplaner) erscheint nichts zum Service.
-- ============================================================================
alter table wissen_kategorie add column if not exists mit_service boolean not null default true;

update wissen_kategorie set mit_service = false
where name in ('Kleber & Dichtstoffe', 'Chemikalien', 'Metall & Befestigung', 'Pflanzen', 'Dünger & Substrate', 'Software & Büro')
  and not exists (select 1 from wissen_service s join wissen_eintrag e on e.id = s.eintrag_id where e.kategorie_id = wissen_kategorie.id);
