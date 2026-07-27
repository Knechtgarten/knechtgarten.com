-- ============================================================================
-- Offertentool 2027 - Generische Zusatzspalte pro Artikel (Zahl + Einheit),
-- z.B. Volumen (30 l), Flaeche (2.5 m2) oder Stueckzahl - fuer Werte, die
-- heute noch nicht in einer Offerten-Berechnung gebraucht werden, aber
-- spaeter als Grundlage fuer eine Formel dienen koennten. Bewusst generisch
-- (nicht "volumen"/"flaeche" als eigene Spalten), weil je nach Lieferant/
-- Artikel ganz unterschiedliche Zusatzwerte relevant sein koennen.
-- ============================================================================

alter table artikel add column zusatzwert numeric;
alter table artikel add column zusatzeinheit text;
