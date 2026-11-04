-- Poolabdeckung Unterflur inkl. Sitzbank: Keramikplatten waren doppelt (zwei Sitzungen).
-- Richtig ist 60 × 120 quer (Zeile e7e0928e). Die Zeile mit 60 × 60 wird gelöscht.
delete from ressourcenzeile where id = '1737cb2f-f8e3-4fd6-97f5-d7c9d7571d16';

select r.reihenfolge, a.bezeichnung from ressourcenzeile r left join artikel a on a.id = r.artikel_id
where r.option_id = '213a1e82-1218-402e-a3ad-e167b029a0f7' order by r.reihenfolge;
