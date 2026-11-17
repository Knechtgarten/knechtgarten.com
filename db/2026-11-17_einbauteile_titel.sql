-- Pool/Wassergarten: Materialzeile in der Offerte «Material Einbauteile wie Skimmer, Düsen, Lampen» (Stefan, 17.11.2026)
update public.arbeitsschritt set titel_offerte = 'Einbauteile wie Skimmer, Düsen, Lampen'
where id = 'eee59350-f742-4f9a-b58c-41d61a39f103'
returning name, titel_offerte;
