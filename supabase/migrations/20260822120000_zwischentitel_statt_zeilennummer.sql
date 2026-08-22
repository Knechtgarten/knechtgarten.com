-- ============================================================================
-- Ersatz fuer "Zeilennummer" (20260822100000): statt jedem Eingabefeld eine
-- Zahl zuzuweisen, die die Zeilenaufteilung im Konfigurator steuert, gibt es
-- jetzt "Zwischentitel" - eigene Zeilen in der Eingabefelder-Liste (gleiche
-- Tabelle, gleiche Drag&Drop-Reihenfolge), die nur einen Namen tragen und im
-- Konfigurator als Zwischenueberschrift erscheinen. Alle danach folgenden
-- Eingabefelder (bis zum naechsten Zwischentitel) beginnen automatisch eine
-- neue Zeile - kein separates Zahlenfeld mehr noetig.
-- ============================================================================

alter table eingabefeld drop column zeilennummer;
alter table eingabefeld add column ist_titel boolean not null default false;
