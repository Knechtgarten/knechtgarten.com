-- ============================================================================
-- Mail-Assistent: Spaltenbreite fuer Zusatzfenster-Spalten (Tabelle mit
-- Auswahlmenue) - Stefan will pro Spalte selbst einschaetzen koennen, ob sie
-- fuer kurzen oder ausfuehrlichen Text gebraucht wird, statt einer fixen
-- Breite fuer alle Spalten.
--
-- Angabe in ungefaehren Zeichen (nicht Pixel) - in Gmail als CSS "ch"-Einheit
-- umgesetzt, das ist fuer Nicht-Techniker leichter einzuschaetzen ("Platz
-- fuer ein Wort oder einen Satz") als eine Pixelzahl.
-- ============================================================================

alter table mailassistent_zusatzfenster_spalte add column if not exists breite int not null default 15;
