-- ============================================================================
-- Offertentool 2027 - Menge-Feld pro Teilbereich
-- Fuer identische Mehrfachvorkommen (z.B. 2 gleiche kleine Becken) - wirkt
-- multiplikativ auf alle Ressourcen-Zeilen dieses Teilbereichs, statt einen
-- zweiten, komplett eigenstaendigen Teilbereich anzulegen.
-- ============================================================================
alter table teilflaeche add column menge numeric not null default 1;
