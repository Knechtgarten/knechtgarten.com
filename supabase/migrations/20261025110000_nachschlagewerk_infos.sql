-- ============================================================================
-- Nachschlagewerk Etappe 3: Baustein «Infos» = Felder pro Kategorie (Tabelle wissen_merkmal).
-- art: text / zahl / datum / janein / auswahl; optionen = Auswahl-Werte; pro_stueck = Feld gehört zum einzelnen Stück
-- (erscheint bei den Angaben des Exemplars), sonst zum Eintrag. Werte bleiben in steckbrief [{label, wert, hinweis}].
-- infos_titel = Überschrift des Bausteins in der Ansicht (leer = «Technische Daten»).
-- Die Felder «für alle Kategorien» entfallen: sie werden in die Geräte- bzw. Produkt-Kategorien kopiert.
-- ============================================================================
alter table wissen_merkmal
  add column if not exists art text not null default 'text' check (art in ('text', 'zahl', 'datum', 'janein', 'auswahl')),
  add column if not exists optionen text[],
  add column if not exists pro_stueck boolean not null default false;
alter table wissen_kategorie add column if not exists infos_titel text;

update wissen_merkmal set art = 'zahl' where einheit is not null and art = 'text';

-- pro Stück, wenn das Feld bisher öfter bei den Exemplaren als beim Eintrag stand
with e as (select en.kategorie_id k, r->>'label' l from wissen_eintrag en, jsonb_array_elements(en.steckbrief) r),
     x as (select en.kategorie_id k, r->>'label' l from wissen_exemplar ex join wissen_eintrag en on en.id = ex.eintrag_id, jsonb_array_elements(ex.steckbrief) r)
update wissen_merkmal m set pro_stueck = true
where m.kategorie_id is not null
  and (select count(*) from x where x.k = m.kategorie_id and x.l = m.name) > (select count(*) from e where e.k = m.kategorie_id and e.l = m.name);

-- Felder «für alle» in die Kategorien verteilen
insert into wissen_merkmal (name, kategorie_id, sortierung, art, einheit, pro_stueck)
select g.name, k.id,
  case g.name when 'Hersteller / Modell' then -10 else 1000 + g.sortierung end,
  case g.name when 'Anschaffungsjahr' then 'zahl' when 'Kaufpreis' then 'zahl' else 'text' end,
  case g.name when 'Kaufpreis' then 'CHF' else g.einheit end,
  g.name <> 'Hersteller / Modell'
from wissen_merkmal g cross join wissen_kategorie k
where g.kategorie_id is null
  and (k.art = 'geraet' or (k.art = 'produkt' and g.name = 'Hersteller / Modell'))
  and not exists (select 1 from wissen_merkmal m where m.kategorie_id = k.id and m.name = g.name);
delete from wissen_merkmal where kategorie_id is null;
