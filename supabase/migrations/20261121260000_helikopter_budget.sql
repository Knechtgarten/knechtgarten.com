-- Helikopter als Budgetbeträge (Stefan 2026-11-21): Air Glaciers CHF 2'500, Rotex K-Max CHF 5'000 (Verkauf, Preis gesperrt).
-- Ersetzt Überflug/Flugminuten/Pauschale in den Helikopter-Optionen (Regenwassertank, Pool-Beckeneinbau).
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht, waehrung, mwst_art, preis_gesperrt, sync_offertentool, notiz)
select 'db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'logistik', v.lnr, v.nr, v.bez, 'Budg', v.vp, 'CHF', 'normal', true, true, v.notiz
from (values
  ('HELI-AG-BUDGET', 'HELI_AIRGLACIERS_BUDGET', 'Budgetbetrag Helikopter Air Glaciers (bis ca. 1000 kg), inkl. Anflug, Installation und Flugminuten', 2500::numeric, 'Erfahrung: Überflug 180.– + 42.–/Min. + Kerosin (Rechnung 167345, Okt. 2026)'),
  ('HELI-RX-BUDGET', 'HELI_ROTEX_BUDGET', 'Budgetbetrag Helikopter Rotex K-Max (über 1000 kg bis 2.5 t), inkl. Überflug, Installation, AVOR, Reko', 5000, 'Erfahrung: Pool Stavro Muri 1.8 t pauschal 3''900.– (Rechnung 79459, Apr. 2026)')
) v(lnr, nr, bez, vp, notiz)
where not exists (select 1 from artikel a where a.artikelnummer_knecht = v.nr);

-- alte Zeilen raus, Budget rein
delete from ressourcenzeile where artikel_id in (select id from artikel where artikelnummer_knecht in ('HELI_AIRGLACIERS_UEBERFLUG', 'HELI_AIRGLACIERS_MINUTE', 'HELI_ROTEX_KMAX'));
insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
select o.id, 'logistik', (select id from artikel where artikelnummer_knecht = case when o.name = 'Helikopter bis 1000 kg' then 'HELI_AIRGLACIERS_BUDGET' else 'HELI_ROTEX_BUDGET' end),
  '{"lit": 1, "_einheit": "Budg"}', 'baukasten', 1, 1, 1, 1, 90
from auswahloption o where o.name in ('Helikopter bis 1000 kg', 'Helikopter über 1000 kg')
  and not exists (select 1 from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = o.id and a.artikelnummer_knecht like 'HELI_%_BUDGET');
update auswahloption set hinweistext = case when name = 'Helikopter bis 1000 kg' then 'Air Glaciers, Budgetbetrag CHF 2''500. Für Lasten bis ca. 1000 kg.' else 'Rotex K-Max, Budgetbetrag CHF 5''000. Für Lasten über 1000 kg bis 2.5 t (z. B. grosse Becken).' end
where name in ('Helikopter bis 1000 kg', 'Helikopter über 1000 kg');
delete from artikel where artikelnummer_knecht in ('HELI_AIRGLACIERS_UEBERFLUG', 'HELI_AIRGLACIERS_MINUTE', 'HELI_ROTEX_KMAX')
  and not exists (select 1 from ressourcenzeile r where r.artikel_id = artikel.id);
