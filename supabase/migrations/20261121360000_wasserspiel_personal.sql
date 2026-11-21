-- Wasserspiel (Pool und Schwimmteich): Polier 6 Std. + Gartenarbeiter 6 Std. statt Polier 4 Std. (Stefan 2026-11-21)
update ressourcenzeile r set menge_ausdruck = '{"lit": 6, "_einheit": "Std."}'
from auswahloption o, artikel ar
where o.id = r.option_id and ar.id = r.artikel_id and o.name in ('Wasserspiel Naturteich', 'Wasserspiel Chemiepool') and ar.artikelnummer_knecht = 'KNECHT_000015';

insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
select o.id, 'personal', ar.id, '{"lit": 6, "_einheit": "Std."}', 'baukasten', 1, 1, 1, 1, 1
from auswahloption o, artikel ar
where o.name in ('Wasserspiel Naturteich', 'Wasserspiel Chemiepool') and ar.artikelnummer_knecht = 'KNECHT_000005'
  and not exists (select 1 from ressourcenzeile r where r.option_id = o.id and r.artikel_id = ar.id);

update auswahloption set hinweistext = replace(hinweistext, '4 Std. Polier', 'Polier und Gartenarbeiter je 6 Std.')
where name in ('Wasserspiel Naturteich', 'Wasserspiel Chemiepool');

select o.name, string_agg(ar.artikelnummer_knecht || '=' || (r.menge_ausdruck->>'lit'), ', ' order by r.reihenfolge) personal, o.hinweistext
from auswahloption o join ressourcenzeile r on r.option_id = o.id join artikel ar on ar.id = r.artikel_id
where o.name in ('Wasserspiel Naturteich', 'Wasserspiel Chemiepool') and r.kategorie = 'personal' group by o.id, o.name, o.hinweistext;

update auswahloption set hinweistext = replace(hinweistext, 'je 6 Std..', 'je 6 Std.') where name in ('Wasserspiel Naturteich', 'Wasserspiel Chemiepool');
