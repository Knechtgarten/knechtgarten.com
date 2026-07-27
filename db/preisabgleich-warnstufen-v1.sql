-- ============================================================================
-- Offertentool 2027 - Globale Warnstufen fuer Preisabweichungen beim
-- Lieferanten-Datenabgleich UND beim Schnellimport (ersetzt die bisherige
-- PRO-LIEFERANT "Toleranzwert Preisabgleich"-Karte mit Prozent/CHF-Feldern).
-- Bewusst eine einzige globale Einstellung statt pro Lieferant, bewusst nur
-- Prozent (kein CHF-Betrag mehr) - zwei Warnstufen statt einem einzelnen
-- Toleranzwert: Stufe 1 (dezente Farbe) und Stufe 2 (deutliche Farbe).
--
-- Singleton-Tabelle: id ist eine boolean-Spalte, die per Check-Constraint nur
-- den Wert true annehmen kann - zusammen mit dem Primary Key ist so technisch
-- erzwungen, dass es immer genau eine Zeile gibt.
-- ============================================================================

create table preisabgleich_warnstufen (
  id boolean primary key default true check (id),
  stufe1_prozent numeric not null default 10,
  stufe2_prozent numeric not null default 25
);

insert into preisabgleich_warnstufen (id) values (true);

alter table preisabgleich_warnstufen enable row level security;
create policy preisabgleich_warnstufen_lesen on preisabgleich_warnstufen
  for select using (ist_eingeloggter_benutzer());
create policy preisabgleich_warnstufen_admin_schreibt on preisabgleich_warnstufen
  for all using (ist_admin()) with check (ist_admin());
