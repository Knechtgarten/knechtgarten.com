-- ============================================================================
-- Neues Feld "Zuschlag %" an der Ressourcenzeile, gleiches Prinzip wie das
-- bestehende "Verschnitt/Auflockerung %" - wirkt auf die MENGE (nicht auf
-- den Preis), damit die Preis-Spalte weiterhin den echten Artikelstamm-Preis
-- zeigt und die Menge-Spalte die tatsaechlich benoetigte Menge inkl.
-- Zuschlag/Verschnitt. Bei einer Staffelgruppe wirkt sich das zusaetzlich
-- auf die Stufen-Ermittlung aus (siehe recalc() in tool-a-live-v1.html) -
-- bisher war dort nur Verschnitt sichtbar/nutzbar, Zuschlag ist komplett neu.
-- ============================================================================

alter table ressourcenzeile add column zuschlag_prozent numeric null;
