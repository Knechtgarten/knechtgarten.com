-- Google-Sheet-Spaltenzuordnung pro Lieferant + Standard-Kategorie fuer neue
-- Artikel (nur relevant bei Datenabgleich-Modus "ergaenzen", da das Sheet
-- selbst keine Kategorie mitliefert).
alter table lieferant_datenabgleich add column sheet_spalten_zuordnung jsonb null;
alter table lieferant_datenabgleich add column kategorie_default text null
  check (kategorie_default in ('material', 'personal', 'maschine', 'logistik'));
