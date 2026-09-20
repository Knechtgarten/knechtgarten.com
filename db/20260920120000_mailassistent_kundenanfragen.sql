-- ============================================================================
-- Mail-Assistent: Grundlage fuer die neue "Kundenanfragen"-Logik (ersetzt die
-- bisherige automatische Distanzlogik/Projekttypen-Stufen). Ein Kundenanfragen-
-- "Topf" ist eine ganz normale mailassistent_vorlage-Zeile mit
-- richtung='kundenanfrage' (gleiche Struktur wie eine Antworten-Vorlage mit
-- Rueckfrage: mehrere Zweige in mailassistent_vorlage_antwort) - dadurch sind
-- spaeter beliebig viele Toepfe moeglich, ohne neue Tabellen zu brauchen. Der
-- Mensch waehlt die passende Antwort danach immer selbst manuell aus einer
-- Liste, die KI liefert nur die Kategorisierung + falls erkennbar die
-- Kundenadresse fuer die Distanzberechnung (keine automatische Text-Wahl
-- mehr wie bisher).
--
-- Die alten Tabellen mailassistent_distanz_projekttyp/_stufe/_meta werden
-- durch dieses Update NICHT geloescht (falls dort noch Daten stehen, die
-- Stefan sich nochmal ansehen will) - der Code verwendet sie einfach nicht
-- mehr. Koennen bei Bedarf spaeter separat entfernt werden.
-- ============================================================================

alter table mailassistent_vorlage drop constraint if exists mailassistent_vorlage_richtung_check;
alter table mailassistent_vorlage add constraint mailassistent_vorlage_richtung_check
  check (richtung in ('verfassen','antworten','kundenanfrage'));

-- Freitext, der bei einem Kundenanfragen-Topf rechts in der Info-Spalte des
-- Gmail-Popups erscheint (ersetzt den bisherigen "Partnerlogik"-Text).
alter table mailassistent_vorlage add column if not exists info_hinweistext text;

-- Hinweis zur Kachel-Uebersicht mit Drag & Drop: keine eigene Spalten-Spalte
-- noetig - die bestehende "reihenfolge" reicht, weil ein zweispaltiges Raster
-- die Position (Zeile+Spalte) allein aus der flachen Reihenfolge ableitet
-- (Position 0/1 = Zeile 1, 2/3 = Zeile 2, usw.), genau wie Gmail die Antworten
-- rendert.
