-- ============================================================================
-- Einsatzplaner: Mithilfe gibt es nie bei einer Ablage-Zeile. Bestehende Mithilfen löschen, deren Termin
-- in einer Ablage-Zeile liegt (entstanden, als der Termin in die Ablage gezogen wurde) – 7 Stück am 2026-11-02.
-- Der Planer fragt künftig beim Ziehen in die Ablage und entfernt die Mithilfe.
-- ============================================================================
delete from planer_einsatz h
using planer_einsatz l, planer_person lp
where h.art = 'hilfe' and l.id = h.mit_einsatz_id and lp.id = l.person_id and lp.ist_ablage;

delete from planer_einsatz h
using planer_person mp
where h.art = 'hilfe' and mp.id = h.mit_person_id and mp.ist_ablage;
