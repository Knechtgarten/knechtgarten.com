-- Summenmodus fuer Staffelgruppen: statt der Menge-Formel EINER Ressourcenzeile
-- (bisheriges Verhalten) bestimmt hier die SUMME eines markierten Zusatzwerts
-- (z.B. "Watt") ueber ALLE aktiven Zeilen eines gewaehlten Bereichs die
-- passende Staffelstufe - z.B. Gesamt-Watt aller gewaehlten Leuchten -> das
-- passende Netzteil. Die eigentliche Stufen-Tabelle (staffelstufe) bleibt
-- unveraendert dieselbe wie bei einer normalen Staffelgruppe.
-- summen_zusatzeinheit = null: normale Staffelgruppe wie bisher (Formel der
-- eigenen Ressourcenzeile bestimmt die Stufe).
-- summen_zusatzeinheit gesetzt (z.B. 'Watt'): Summenmodus - zaehlt bei jedem
-- aktiven Artikel mit genau dieser Zusatzeinheit dessen Zusatzwert x Menge
-- zusammen (siehe Tool A recalc()).
alter table staffelgruppe add column summen_zusatzeinheit text null;
alter table staffelgruppe add column summen_scope text null check (summen_scope in ('offerte', 'arbeitsschritt'));
