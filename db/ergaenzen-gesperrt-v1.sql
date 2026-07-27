-- ============================================================================
-- Offertentool 2027 - Sperre fuer "Daten ergaenzen" pro Lieferant.
--
-- Bei manchen Quellen (v.a. PDF-Preislisten ohne vorherige Kuratierung wie
-- bei einer Merkliste) besteht das Risiko, dass aus Versehen sehr viele neue
-- Artikel auf einmal vorgeschlagen werden, wenn ein Mitarbeiter unbedacht
-- den Modus "Daten ergaenzen" anwaehlt. Ein Admin kann das darum pro
-- Lieferant explizit sperren - der Abgleich laeuft dann immer im
-- 1:1-Abgleich, unabhaengig vom zuletzt gespeicherten crawling_modus.
-- ============================================================================

alter table lieferant_datenabgleich add column ergaenzen_gesperrt boolean not null default false;
