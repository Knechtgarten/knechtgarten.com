-- ============================================================================
-- Offertentool 2027 - Standard-Marge pro Lieferant wieder entfernt: die Marge
-- kann je nach Artikel stark variieren, ein einzelner Standardwert pro
-- Lieferant war darum nicht sinnvoll nutzbar. Das Feld "Marge Lieferant %
-- (Standard)" war in der Oberflaeche noch bei keinem Lieferanten befuellt.
-- Der bisherige "Minimum-Marge %"-Mechanismus (jetzt "(Minimum-)Marge
-- Knecht %" genannt) bleibt unveraendert bestehen.
-- ============================================================================

alter table lieferant_datenabgleich drop column marge_lieferant_standard_prozent;
