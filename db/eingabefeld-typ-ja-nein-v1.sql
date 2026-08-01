-- ============================================================================
-- Offertentool 2027 - Eingabefeld-Typ "Ja/Nein" (Checkbox statt Zahl-Eingabe).
-- Zweck: fixe Werte (z.B. Mauerdicke Coffra = 18cm, als Term hinterlegt)
-- sollen im Formel-Zug nur EINGERECHNET werden, wenn der Mitarbeiter in
-- Tool A ein einfaches Ja/Nein-Feld anhakt - der fixe cm-Wert selbst bleibt
-- fuer den Mitarbeiter nicht veraenderbar. Loesung: der Term (z.B. "Mauerdicke
-- Coffra") wird mit dem neuen Ja/Nein-Eingabefeld multipliziert (× 0/× 1) -
-- kein neuer Formel-Knotentyp noetig, nur ein neues Eingabefeld, das statt
-- einer Zahl 0 oder 1 liefert.
-- ============================================================================

alter table eingabefeld add column typ text not null default 'zahl' check (typ in ('zahl','ja_nein'));
