-- ============================================================================
-- Offertentool 2027 - Explizite Preis-Sperre pro Artikel statt impliziter
-- Erkennung ("entspricht der Wert noch der alten Formel?"). Ein Artikel mit
-- preis_gesperrt = true wird NIE von einer automatischen Neuberechnung von
-- VP Knecht angefasst (egal ob ueber Sondermarge % oder eine direkt
-- eingetippte Zahl geschuetzt) - weder von der Auto-Ergaenzung beim
-- Speichern der Lieferant-Details noch von einer kuenftigen "Alle neu
-- berechnen"-Funktion. Wird in der Artikelübersicht als Schloss-Symbol
-- angezeigt.
-- ============================================================================

alter table artikel add column preis_gesperrt boolean not null default false;
