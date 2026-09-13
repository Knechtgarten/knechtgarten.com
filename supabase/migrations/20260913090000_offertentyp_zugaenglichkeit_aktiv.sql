-- ============================================================================
-- Manche Offertentypen (z.B. "Bewaesserung ohne Grabarbeiten") kennen
-- praktisch nie unterschiedliche Zugaenglichkeit vor Ort - der Regler in der
-- Offerte haette dort nie einen Einfluss und wirkt nur verwirrend. Pro
-- Offertentyp in Tool B abschaltbar - blendet dann sowohl den Zugaenglich-
-- keits-Regler in der Offerte (Tool A) als auch das Zugaenglichkeitsfaktor-
-- Feld je Ressourcenzeile (Tool B) aus. Reine Sichtbarkeits-Einstellung: die
-- Berechnung selbst aendert sich nicht (Stufe/Faktoren bleiben auf ihren
-- neutralen Standardwerten 2 bzw. 1, siehe tool-a-live-v1.html).
-- ============================================================================

alter table offertentyp add column zugaenglichkeit_aktiv boolean not null default true;
