-- ============================================================================
-- Nachschlagewerk Etappe 2: Rubriken und Bausteine
-- art = Rubrik der Kategorie (geraet / produkt / wissen / neu: kurz für Kurzinfo).
-- bausteine = Reihenfolge der Bausteine mit Anzeige: [{"k":"notizen","m":"offen"|"zu"}, …]; nicht aufgeführt = Aus.
--   Ersetzt abschnitt_reihe / offen_pc / offen_handy (bleiben ungenutzt stehen).
-- links = Weblinks des Eintrags (Baustein «Dokumente & Links»): [{"titel":…, "url":…}]
-- Jeder Eintrag hat mindestens ein Exemplar (für Link und Etikette auch bei Produkten und Wissen).
-- ============================================================================
alter table wissen_kategorie drop constraint if exists wissen_kategorie_art_check;
alter table wissen_kategorie add constraint wissen_kategorie_art_check check (art in ('geraet', 'produkt', 'wissen', 'kurz'));
alter table wissen_kategorie add column if not exists bausteine jsonb;

update wissen_kategorie k set bausteine = (
  select jsonb_agg(jsonb_build_object('k', t, 'm',
    case when t like 'x\_%' or t = any(coalesce(k.offen_pc, array['notizen', 'steck'])) then 'offen' else 'zu' end) order by ord)
  from unnest(coalesce(k.abschnitt_reihe, array['x_angaben', 'x_service', 'x_notizen', 'notizen', 'sicher', 'steck', 'anw', 'service', 'kontakte', 'docs'])) with ordinality u(t, ord)
) where k.bausteine is null;

alter table wissen_eintrag add column if not exists links jsonb not null default '[]';

insert into wissen_exemplar (eintrag_id, sortierung)
select e.id, 10 from wissen_eintrag e where not exists (select 1 from wissen_exemplar x where x.eintrag_id = e.id);
