-- ============================================================================
-- Offertentool 2027 - Referenzwert fuer Staffelung wieder entfernt.
--
-- Der Referenzwert an der Staffelgruppe (z.B. "immer Volumen Betonbodenplatte")
-- hatte Vorrang vor der Menge-Formel der jeweiligen Ressourcenzeile - genau
-- das Gegenteil von dem, was gebraucht wird: dieselbe Staffelgruppe (z.B.
-- Betonpumpe) wird oft fuer unterschiedliche Werte eingesetzt (mal Poolboden-,
-- mal Poolwand-Volumen). Zudem verlangte das Erfassen einer neuen Sonder-
-- position IMMER eine gueltige Menge-Formel, auch wenn sie durch den
-- Referenzwert sowieso ignoriert worden waere - das fuehrte dazu, dass sich
-- gar nichts mehr speichern liess. Ab jetzt bestimmt ausschliesslich die
-- Menge-Formel der jeweiligen Ressourcenzeile die Staffelstufe (frueher: das
-- Verhalten "ohne Referenzwert").
-- ============================================================================

alter table staffelgruppe drop column if exists referenz_eingabefeld_id;
alter table staffelgruppe drop column if exists referenz_term_id;
alter table eingabefeld drop column if exists staffel_referenz;
alter table term drop column if exists staffel_referenz;
