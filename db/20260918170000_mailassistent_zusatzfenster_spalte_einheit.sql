-- ============================================================================
-- Mail-Assistent: Einheit fuer Mengenspalten (typ='zahl') im Zusatzfenster.
--
-- Eine Mengenspalte (z.B. Kabellaenge) hat keine Dropdown-Optionen, sondern
-- eine freie Einheit (z.B. "Meter", "Stueck"), die in Gmail neben dem
-- Zahlenfeld angezeigt wird.
-- ============================================================================

alter table mailassistent_zusatzfenster_spalte
  add column if not exists einheit text;
