-- ============================================================================
-- Offertentool 2027 - Warnschwelle fuer den Preisabgleich pro Lieferant.
-- Bei einem Abgleich wird ein Artikel als "grosse Abweichung" markiert, wenn
-- er entweder den Prozent- ODER den CHF-Schwellenwert ueberschreitet (CHF
-- optional, da bei kleinen Artikeln ein Prozentwert allein wenig aussagt).
-- ============================================================================

alter table lieferant_datenabgleich add column warnschwelle_prozent numeric not null default 15;
alter table lieferant_datenabgleich add column warnschwelle_betrag_chf numeric null;
