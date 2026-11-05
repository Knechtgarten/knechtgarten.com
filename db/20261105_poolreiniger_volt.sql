-- Pooloptionen › Poolroboter: Akku-Poolreiniger Volt FX-8 Li als eigene Auswahl (wie die Roboter: 1 Std Instruktion, eigene Offertenposition)
update public.auswahloption set reihenfolge = 4 where auswahlfeld_id = '56621d27-607c-4b56-9c5e-d6de1d6f0a19' and name = 'Reinigungsset';
with o as (
  insert into public.auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, hinweisbild_url, mehrfachauswahl, ist_eigene_offertenposition, mengenoption)
  select '56621d27-607c-4b56-9c5e-d6de1d6f0a19', 'Volt FX-8 Li (Akku-Handreiniger)', 3,
    'Akku-Poolreiniger Volt FX-8 Li inkl. Ladegerät und Filterbeutel liefern, in Betrieb nehmen und Bedienung instruieren.',
    'Akku-Poolreiniger für die Handreinigung an der Teleskopstange, mit Ladegerät.', a.foto_url, false, true, false
  from public.artikel a where a.id = 'ee488e71-a885-45a9-aadd-4b8ae7febe75'
  returning id)
insert into public.ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge, ist_eigene_offertenposition, menge_formel_modus, mengenoption_ausgenommen)
select o.id, x.k, x.a::uuid, x.m::jsonb, 1, 1, 1, 1, x.r, false, 'baukasten', false
from o, (values ('personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a', '{"lit": 1, "_einheit": "Std."}', 1),
                ('material', 'ee488e71-a885-45a9-aadd-4b8ae7febe75', '{"lit": 1, "_einheit": "Stk."}', 2)) as x(k, a, m, r);
