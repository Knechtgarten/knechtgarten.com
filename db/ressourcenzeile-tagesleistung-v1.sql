-- ============================================================================
-- Offertentool 2027 - Tagessatz-Offerten auf Formel-Struktur umstellen (Teil 1).
--
-- Tagessatz-Offerten ("Allgemein") nutzen kuenftig dieselbe Struktur wie
-- Formel-Offerten (arbeitsschritt > teilschritt > auswahlfeld > auswahloption
-- > ressourcenzeile mit Artikelbezug), statt eigener flacher Felder direkt
-- auf arbeitsschritt (tagessatz_material/_maschine/_baumaschine/_lieferwagen).
--
-- Der einzige Unterschied zur Formel-Menge (menge_ausdruck, ein Formel-Baum
-- ueber Eingabefelder/Terms, ausgewertet per eval_ausdruck): bei Tagessatz
-- ist die Menge schlicht "Tagesleistungsmenge x Anzahl Tage" - keine Formel
-- noetig, reine Client-seitige Multiplikation. Deshalb ein eigenes, simples
-- Feld statt Wiederverwendung von menge_ausdruck (klarere Semantik: pro
-- Ressourcenzeile ist immer genau eines der beiden Felder gesetzt).
-- ============================================================================

alter table ressourcenzeile add column tagesleistung_menge numeric null;

-- menge_ausdruck war bisher immer gesetzt (nur Formel-Ressourcenzeilen gab es).
-- Bei Tagessatz-Ressourcenzeilen bleibt es leer, dafuer ist tagesleistung_menge
-- gesetzt - also muss die NOT-NULL-Bedingung entfallen.
alter table ressourcenzeile alter column menge_ausdruck drop not null;

-- Klare Konsistenzregel: genau eines der beiden Felder ist gesetzt, nie beide,
-- nie keines.
alter table ressourcenzeile add constraint ressourcenzeile_menge_check check (
  (menge_ausdruck is not null and tagesleistung_menge is null) or
  (menge_ausdruck is null and tagesleistung_menge is not null)
);
