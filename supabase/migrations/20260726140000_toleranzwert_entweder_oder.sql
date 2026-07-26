-- ============================================================================
-- Offertentool 2027 - Toleranzwert Preisabgleich: Prozent/CHF sind ein
-- Entweder-Oder-Paar (nie beide gleichzeitig). "Abweichung %" war bisher
-- NOT NULL mit Default 15 und liess sich darum nie wirklich leeren, wenn
-- stattdessen "Abweichung CHF" verwendet werden sollte.
-- ============================================================================

alter table lieferant_datenabgleich alter column warnschwelle_prozent drop not null;
