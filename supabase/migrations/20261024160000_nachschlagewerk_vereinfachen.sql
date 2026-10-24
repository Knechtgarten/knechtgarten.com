-- ============================================================================
-- Nachschlagewerk vereinfachen:
-- 1) Art (Gerät / Produkt / Wissen) pro Kategorie statt pro Eintrag; neue Kategorie «Wissen & Daten».
-- 2) Bereiche und Tags werden zu «Stichwörtern» (Spalte tags): Bereichsnamen kommen dazu,
--    Herstellernamen fallen weg (stehen im Untertitel; wo der leer ist, wandert der Hersteller dorthin).
--    bereich_ids / wissen_bereich bleiben vorerst ungenutzt stehen.
-- 3) Eine Notiz pro Eintrag bzw. Exemplar: mehrere werden zusammengefasst (neueste oben, mit Datum).
-- ============================================================================

-- 1) Art pro Kategorie
alter table wissen_kategorie add column if not exists art text not null default 'geraet' check (art in ('geraet', 'produkt', 'wissen'));
update wissen_kategorie set art = 'produkt'
where name in ('Kleber & Dichtstoffe', 'Chemikalien', 'Metall & Befestigung', 'Dünger & Substrate', 'Pflanzen');
insert into wissen_kategorie (name, sortierung, art)
select 'Wissen & Daten', coalesce(max(sortierung), 0) + 10, 'wissen' from wissen_kategorie
where not exists (select 1 from wissen_kategorie where name = 'Wissen & Daten');
update wissen_eintrag e set typ = k.art from wissen_kategorie k where k.id = e.kategorie_id and e.typ <> k.art;

-- 2) Stichwörter
with hersteller as (
  select e.id, (array_agg(t order by t))[1] h
  from wissen_eintrag e, unnest(e.tags) t
  where t not in ('Akku', 'Anbaugerät')
  group by e.id
)
update wissen_eintrag e set untertitel = h.h
from hersteller h where h.id = e.id and coalesce(trim(e.untertitel), '') = '';

update wissen_eintrag e set tags = array(
  select distinct x from (
    select unnest(e.tags) x
    union select b.name from wissen_bereich b where b.id = any(e.bereich_ids)
  ) s
  where x in ('Akku', 'Anbaugerät') or x in (select name from wissen_bereich)
  order by x
);

-- gespeicherte Listen: Filter «Bereich» -> Filter «Stichwort»
update wissen_liste l set filter = (l.filter - 'bers') || jsonb_build_object('stw',
  coalesce((select jsonb_agg(b.name) from wissen_bereich b where b.id::text in (select jsonb_array_elements_text(l.filter->'bers'))), '[]'::jsonb))
where l.filter ? 'bers';

-- 3) Notizen zusammenfassen
with gruppen as (
  select eintrag_id, exemplar_id,
    (array_agg(id order by erstellt_am desc))[1] behalten,
    string_agg('<p><b>' || to_char(erstellt_am, 'DD.MM.YYYY') || ':</b></p>' || coalesce(html, ''), '' order by erstellt_am desc) html
  from wissen_notiz group by eintrag_id, exemplar_id having count(*) > 1
), dateien as (
  update wissen_datei d set notiz_id = g.behalten
  from wissen_notiz n join gruppen g on g.eintrag_id = n.eintrag_id and g.exemplar_id is not distinct from n.exemplar_id
  where d.notiz_id = n.id and n.id <> g.behalten
  returning d.id
), zusammen as (
  update wissen_notiz n set html = g.html from gruppen g where n.id = g.behalten returning n.id
)
delete from wissen_notiz n using gruppen g
where g.eintrag_id = n.eintrag_id and g.exemplar_id is not distinct from n.exemplar_id and n.id <> g.behalten;
