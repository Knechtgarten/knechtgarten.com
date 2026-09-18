-- ============================================================================
-- Mail-Assistent: Spaltentyp fuer Zusatzfenster-Spalten.
--
-- Bisher war jede Zusatzspalte automatisch ein Dropdown mit fest hinterlegten
-- Optionen. Manche Spalten (z.B. "Kabellaenge in Metern") brauchen aber ein
-- freies Zahlenfeld statt einer Auswahl - "typ" unterscheidet das.
-- ============================================================================

alter table mailassistent_zusatzfenster_spalte
  add column if not exists typ text not null default 'dropdown' check (typ in ('dropdown','zahl'));
