-- Einsatzplaner: Schnupper / Temporär voll planbar – offene Linie wie Gartenbau, bestehende Zeilen ohne Farbe bekommen einen Erd-Ton
update public.planer_gruppe set offene_linie = true where name ilike '%schnupper%' or name ilike '%tempor%';
update public.planer_person p set farbe = '#BE9E80'
  from public.planer_gruppe g
 where g.id = p.gruppe_id and (g.name ilike '%schnupper%' or g.name ilike '%tempor%')
   and p.farbe is null and not coalesce(p.ist_ablage, false) and p.aktiv;
