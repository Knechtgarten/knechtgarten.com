-- ============================================================================
-- Offertentool 2027 - Einheit fuer Mengenoptionen frei waehlbar statt fest
-- "Stk." - bei einer Option mit nur einer einzigen, homogenen Ressourcenzeile
-- (z.B. nur ein Artikel in m3) ist "Stk." irrefuehrend; bei mehreren
-- verschiedenen Ressourcenzeilen (Personal in Std + Material in m3 gemischt)
-- bleibt "Stk." dagegen die einzig sinnvolle Einheit.
-- ============================================================================

alter table auswahloption add column mengenoption_einheit text not null default 'Stk.';
