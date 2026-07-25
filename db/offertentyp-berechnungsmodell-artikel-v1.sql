-- ============================================================================
-- Offertentool 2027 - Dritter Offertentyp "Offerten laut Artikeln".
--
-- Die bestehende CHECK-Constraint auf offertentyp.berechnungsmodell erlaubte
-- bisher nur 'formel' (Mengenberechnung, Tool A) und 'tagessatz'
-- (Tagesberechnung/"Allgemein", Tool A2). Neu kommt 'artikel' dazu (schlanker
-- dritter Typ: Artikel direkt aus dem Artikelstamm listen, kein Formel-/
-- Tagesleistungs-Konzept, kein Tool-B-Template noetig).
-- ============================================================================

alter table offertentyp drop constraint offertentyp_berechnungsmodell_check;
alter table offertentyp add constraint offertentyp_berechnungsmodell_check
  check (berechnungsmodell in ('formel','tagessatz','artikel'));
