-- Einmalig nach dem Einschalten der Regel (Stefan, 18.11.2026)
-- 1) Spezial-Rollrasen: VP 25 stimmt, EP 20 % tiefer (25 → 20), Schloss zu (sonst rechnet die Regel 20 ÷ 0.7 = 29)
insert into public.artikel_preis_verlauf (artikel_id, alter_preis, neuer_preis, quelle, lieferant_id)
select id, ep_lieferant, 20, 'artikelstamm', lieferant_id from public.artikel where bezeichnung = 'Spezial-Rollrasen 0-20m2' and ep_lieferant = 25;
update public.artikel set ep_lieferant = 20, vp_knecht = 25, preis_gesperrt = true where bezeichnung = 'Spezial-Rollrasen 0-20m2' returning bezeichnung, ep_lieferant, vp_knecht, preis_gesperrt;

-- 2) Alle Artikel mit offenem Schloss auf die Regel bringen (Grütter 40 % Marge, B-Team, kleine Rundungsreste)
update public.artikel a set vp_knecht = s.v
from (select id, public.vp_knecht_vorschlag(lieferant_id, ep_lieferant, vp_lieferant, waehrung) v from public.artikel where not coalesce(preis_gesperrt, false)) s
where a.id = s.id and s.v is not null and a.vp_knecht is distinct from s.v;

select bezeichnung, ep_lieferant, vp_knecht, preis_gesperrt from public.artikel
where bezeichnung ilike 'Stirnverblendung%' or bezeichnung ilike 'Montagematerial Stirnverblendung%' or bezeichnung ilike 'Isolation EUROBATEX 19mm%'
   or bezeichnung ilike 'Optiflex-Profix Optipress-Übergang%' or bezeichnung ilike 'JANOlen nero PE-HD Abzweiger 88.5°%D 110/110' or bezeichnung ilike 'Spezial-Rollrasen%' or bezeichnung ilike 'Panzerschlauch-Butyl, 3/4%500%'
order by bezeichnung;
