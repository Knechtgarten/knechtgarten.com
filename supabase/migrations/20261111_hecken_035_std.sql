-- Bepflanzung › Hecken: Polier und Gartenarbeiter neu 0.35 Std. pro Hecke Total (vorher 0.3), alle Arten und Grössen
update ressourcenzeile r set menge_ausdruck = jsonb_set(r.menge_ausdruck, '{args,1,lit}', '0.35'::jsonb),
  menge_formel_baukasten_ausdruck = case when r.menge_formel_baukasten_ausdruck is not null and r.menge_formel_baukasten_ausdruck = r.menge_ausdruck
    then jsonb_set(r.menge_formel_baukasten_ausdruck, '{args,1,lit}', '0.35'::jsonb) else r.menge_formel_baukasten_ausdruck end
from artikel a
where a.id = r.artikel_id and r.kategorie = 'personal'
  and r.menge_ausdruck->'args'->0->>'id' = '56060bae-148c-47d1-8a76-0068f4d74b51'
  and (r.menge_ausdruck->'args'->1->>'lit')::numeric = 0.3
  and a.bezeichnung in ('Gartenarbeiter', 'Polier / Vorarbeiter');
