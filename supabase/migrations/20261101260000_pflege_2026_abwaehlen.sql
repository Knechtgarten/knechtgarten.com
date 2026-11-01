-- ============================================================================
-- Pflege: alle Arbeiten der Pflegekunden für 2026 abwählen (Wunsch Stefan, 2026-11-01)
-- 2026 wird im Planer nicht live geplant; ab 2027 erscheinen die Arbeiten wieder als offene Termine.
-- Zurück: update pflege_kunde_arbeit set abgewaehlte_jahre = array_remove(abgewaehlte_jahre, 2026);
-- ============================================================================
update pflege_kunde_arbeit
set abgewaehlte_jahre = array_append(coalesce(abgewaehlte_jahre, '{}'), 2026)
where not (2026 = any(coalesce(abgewaehlte_jahre, '{}')));
