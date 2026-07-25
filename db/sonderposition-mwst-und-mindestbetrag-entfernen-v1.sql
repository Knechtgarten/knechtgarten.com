-- ============================================================================
-- Offertentool 2027 - Zwei Korrekturen:
--
-- 1) MwSt-Satz (Referenzwert, wie bei Artikel/Lieferant schon vorhanden) fehlt
--    bisher bei Kies-/Beton-Transport, da kein Artikel vorhanden ist, der ihn
--    mitbringen wuerde. Wird vorerst nur gespeichert/angezeigt - die
--    tatsaechliche Anwendung passiert erst ganz am Schluss bei der
--    Totalisierung der Offerte (separates, noch offenes Thema).
--
-- 2) "Mindestbetrag" pro Kieswerk war architektonisch am falschen Ort und
--    inhaltlich falsch (sollte eine Mindestmenge/-volumen sein, nicht ein
--    CHF-Betrag) - dafuer gibt es bereits ressourcenzeile.mindestmenge auf
--    Vorlagen-Ebene (Tool B), analog zur Mengen-Formel bei der Betonpumpe.
--    Die Kieswerk-Tabellen brauchen dieses Feld deshalb gar nicht.
-- ============================================================================

alter table sonderposition_typ add column mwst_satz_pct numeric not null default 8.1;

alter table kieswerk_kies drop column mindestbetrag;
alter table kieswerk_beton drop column mindestbetrag;
