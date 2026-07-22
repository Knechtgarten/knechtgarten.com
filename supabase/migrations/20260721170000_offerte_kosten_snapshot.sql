-- ============================================================================
-- Offertentool 2027 - Eingefrorener Kosten-Snapshot pro Offerte
--
-- Bisher wurde eine bestehende Offerte beim Oeffnen IMMER live neu berechnet -
-- mit den JEWEILS AKTUELLEN Artikelpreisen/Formeln/Einstellungen, nicht mit
-- dem Stand von damals. Das ist ein reales Risiko: bereits an Kunden
-- verschickte Offerten duerften sich rueckwirkend still veraendern, sobald
-- irgendwo im Katalog (Tool B/C, Einstellungen) etwas angepasst wird.
--
-- Ab jetzt wird die komplette berechnete Kostentabelle beim Speichern als
-- fixer Schnappschuss mitgespeichert. Eine bestehende Offerte zeigt beim
-- Oeffnen diesen eingefrorenen Stand (nur Anzeige) - erst ein bewusster Klick
-- auf "Bearbeiten" schaltet auf die normale, live berechnende Eingabe-Ansicht
-- um, und erst ein erneutes Speichern ueberschreibt den Snapshot.
-- ============================================================================

alter table offerte add column kosten_snapshot jsonb null;
