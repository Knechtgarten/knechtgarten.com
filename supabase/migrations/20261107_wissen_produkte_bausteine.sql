-- Nachschlagewerk: bei Produkten und Wissen gehören technische Daten und Anwendung in die Notizen
-- (Abschnitt heisst dort «Notizen, Anwendung, technische Daten»). Bausteine «steck» und «anw» entfernen.
-- Stand 2026-11-07: kein Produkt- oder Wissens-Eintrag hatte dort Inhalt. Geräte bleiben unverändert.
update wissen_kategorie k
set bausteine = (select coalesce(jsonb_agg(b), '[]'::jsonb) from jsonb_array_elements(k.bausteine) b where b->>'k' not in ('steck', 'anw'))
where k.art in ('produkt', 'wissen') and k.bausteine is not null;
