-- ============================================================================
-- Offertentool 2027 - Mindestmenge + Verschnitt/Auflockerung % pro Ressourcenzeile
-- Beide Felder bleiben leer (null) im Normalfall - ein Leerfeld bedeutet
-- "kein Einfluss", nicht 0 als aktiv eingetragener Wert.
-- Verschnitt/Auflockerung %: multipliziert die berechnete Menge zusaetzlich
-- (z.B. 10 bedeutet Menge x 1.1).
-- Mindestmenge: hebt die fertig berechnete Menge (inkl. Verschnitt,
-- Zugaenglichkeits-Faktor, Teilbereich-Menge) auf diesen Wert an, falls sie
-- kleiner waere - z.B. "mindestens 1 Mulde", auch wenn rechnerisch weniger
-- noetig waere.
-- ============================================================================
alter table ressourcenzeile add column mindestmenge numeric null;
alter table ressourcenzeile add column verschnitt_prozent numeric null;
