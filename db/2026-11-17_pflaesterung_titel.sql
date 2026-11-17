-- Beläge: Materialzeile in der Offerte «Material Pflästerung inkl. Bettungsschicht» statt «Material Pflästerung» (Stefan, 17.11.2026)
-- titel_offerte = alternativer Titel nur für die Offerte, der interne Arbeitsschritt-Name bleibt «Pflästerung»
update public.arbeitsschritt set titel_offerte = 'Pflästerung inkl. Bettungsschicht'
where id = '68206612-a6c4-464c-8f29-958af149628b'
returning name, titel_offerte;
