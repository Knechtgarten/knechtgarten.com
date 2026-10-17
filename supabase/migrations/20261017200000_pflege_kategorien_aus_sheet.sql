-- ============================================================================
-- Pflege-Tool: Kategorien + Standardarbeiten aus dem Sheet «Dauerpflegekunden mit Abo»
-- (Entscheide Nutzer 2026-10-17). Beispiel-Standardarbeiten aus dem Mockup werden
-- ersetzt; Bewaesserung Aus-/Einwintern bleiben (mit Ablauf), nur Standard-Wochen neu.
-- Standard-Wochen = Wochen, die mindestens die Haelfte der Kunden mit dieser Arbeit hat.
-- ============================================================================
update pflege_kategorie set name = 'Pool', kuerzel = 'PO' where name = 'Poolservice';
update pflege_kategorie set name = 'Biopool', kuerzel = 'BP' where name = 'Schwimmteich';
update pflege_kategorie set reihenfolge = 20 where name = 'Individuell';
insert into pflege_kategorie (name, kuerzel, farbe, reihenfolge) values
  ('Rasen', 'RA', '#8DB255', 7),
  ('Solitärbaumpflege', 'SB', '#5E7D4B', 8),
  ('Nematoden', 'NE', '#9A7BB5', 9),
  ('Zünsler', 'ZU', '#C28B5A', 10),
  ('Fischteich', 'FT', '#4F8FA8', 11),
  ('Zierbecken/Brunnen', 'ZB', '#7AA6C2', 12);

delete from pflege_arbeit a using pflege_kategorie k
 where k.id = a.kategorie_id
   and not (k.name = 'Bewässerung' and a.name in ('Auswintern / Inbetriebnahme', 'Einwintern / Ausblasen'));
update pflege_arbeit set standard_kws = '{13}', reihenfolge = 1 where name = 'Auswintern / Inbetriebnahme' and kategorie_id = (select id from pflege_kategorie where name = 'Bewässerung');
update pflege_arbeit set standard_kws = '{44}', reihenfolge = 2 where name = 'Einwintern / Ausblasen' and kategorie_id = (select id from pflege_kategorie where name = 'Bewässerung');
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Fräsen', '{14}', 1 from pflege_kategorie where name = 'Biopool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Rückspülung', '{38}', 2 from pflege_kategorie where name = 'Biopool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Fischteich', '{12}', 1 from pflege_kategorie where name = 'Fischteich';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Heckenschnitt', '{33}', 1 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Kübelpflanzen', '{17,43}', 2 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Pflege', '{}', 3 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Rosen schneiden', '{12}', 4 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Sommerschnitt', '{27}', 5 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Töpfe bepflanzen', '{23,43}', 6 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Wiese mähen', '{25,38}', 7 from pflege_kategorie where name = 'Gartenpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Nematoden', '{20,39}', 1 from pflege_kategorie where name = 'Nematoden';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Dusche', '{44}', 1 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Einwintern', '{43}', 2 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Inbetriebnahme', '{12}', 3 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Kontrolle Wasser', '{4,14,18,22,26,30,34,38,42,49}', 4 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Kontrolle, Kalibrierung', '{22}', 5 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Pool Reinigung', '{14}', 6 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'UV-C wechseln', '{12}', 7 from pflege_kategorie where name = 'Pool';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Rasen Delux', '{12,24,26,35,37}', 1 from pflege_kategorie where name = 'Rasen';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Rasen mähen', '{13,15,17,19,21,23,25,27,29,32,35,38,41,44}', 2 from pflege_kategorie where name = 'Rasen';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Solitärbaumpflege', '{13,18,29,38}', 1 from pflege_kategorie where name = 'Solitärbaumpflege';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Winterschnitt', '{4}', 1 from pflege_kategorie where name = 'Winterschnitt';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Entleerung & Reinigung', '{38}', 1 from pflege_kategorie where name = 'Zierbecken/Brunnen';
insert into pflege_arbeit (kategorie_id, name, standard_kws, reihenfolge) select id, 'Zünsler', '{18,29,38}', 1 from pflege_kategorie where name = 'Zünsler';
