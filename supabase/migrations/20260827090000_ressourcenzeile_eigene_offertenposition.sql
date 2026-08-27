-- ============================================================================
-- "Eigene Offertenposition" (bisher nur auf Auswahloption-Ebene) neu auch
-- auf Artikel-Ebene: eine einzelne Ressourcenzeile kann per Stecknadel-Icon
-- (Tool B) markiert werden, damit sie in Tool A (Formel) als eigene Zeile
-- statt im Materialpaket/Logistikaufwand ihres Arbeitsschritts erscheint -
-- unabhaengig davon, ob ihre Option ebenfalls "eigene Position" ist (siehe
-- Absprache: Artikel-Ebene hat Vorrang, der Rest der Option bzw. des
-- Arbeitsschritts wird jeweils ohne den herausgeloesten Artikel berechnet).
-- Gilt fuer die Kategorien Material und Logistik (Personal/Maschine
-- bewusst nicht, wie bei der bestehenden Options-Ebene-Funktion).
-- ============================================================================

alter table ressourcenzeile add column ist_eigene_offertenposition boolean not null default false;
