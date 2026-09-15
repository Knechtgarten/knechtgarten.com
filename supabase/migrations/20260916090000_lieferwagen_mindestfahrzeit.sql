-- ============================================================================
-- Mindestfahrzeit pro Fahrt fuer die Lieferwagenfahrzeit-Berechnung (Tool A).
--
-- Bisher wurde die von Google Distance Matrix gelieferte Fahrzeit 1:1
-- verrechnet - bei sehr kurzen Strecken (z.B. Kunde im selben Dorf wie die
-- Firma) rundet das nach rundeMenge() auf 0 Std, obwohl real immer ein
-- gewisser Mindestaufwand pro Fahrt anfaellt (Ein-/Aussteigen, Parkieren,
-- Anfahrt innerorts). mindestfahrzeit_min gilt PRO FAHRT (also pro
-- Einzelstrecke, nicht schon fuer Hin+Rueck kombiniert) und wird in Tool A
-- als Untergrenze auf die von Google gelieferte Einweg-Fahrzeit angewendet,
-- bevor auf Hin+Rueck verdoppelt wird.
-- ============================================================================

alter table lieferwagen_konfiguration add column mindestfahrzeit_min numeric null;
