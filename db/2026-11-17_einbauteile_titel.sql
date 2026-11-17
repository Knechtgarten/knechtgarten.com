-- Pool/Wassergarten: Materialzeile in der Offerte «Material Einbauteile wie Skimmer, Düsen, Lampen» (Stefan, 17.11.2026)
update public.arbeitsschritt set titel_offerte = 'Einbauteile wie Skimmer, Düsen, Lampen'
where id = 'eee59350-f742-4f9a-b58c-41d61a39f103'
returning name, titel_offerte;

-- Naturteich/Schwimmteich: gleicher Offerten-Titel
update public.arbeitsschritt set titel_offerte = 'Einbauteile wie Skimmer, Düsen, Lampen'
where id = '3e2bafe4-2a54-42c7-8bc5-9737577d0ac7'
returning name, titel_offerte;
