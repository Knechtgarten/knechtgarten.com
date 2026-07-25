-- ============================================================================
-- Offertentool 2027 - Vorlage (offertentyp) bekommt einen Schalter
-- "Teilbereiche moeglich".
--
-- Grund: Nur wenn dieser Schalter aktiv ist, zeigt Tool A die Moeglichkeit,
-- mehrere Teilbereiche (Mini-Offerten mit eigener Kostenaufstellung) pro
-- Offerte anzulegen, und Tool B zeigt bei den Ressourcenzeilen die
-- "Teilflaechen-Kombination"-Spalte (TF). Fuer Vorlagen, bei denen mehrere
-- Teilbereiche keinen fachlichen Sinn ergeben (oder noch nicht durchdacht
-- sind), bleibt die Funktion so unsichtbar - kein Risiko fuer versehentliche
-- Fehlbedienung oder Rechnungsfehler.
--
-- Bestehende Formel-Vorlagen (z.B. "Pool/Wasseranlagen") nutzen Teilbereiche
-- bereits produktiv - deshalb bei denen automatisch aktiviert, damit sich am
-- Verhalten nichts aendert. Neue Vorlagen starten bewusst deaktiviert, bis ein
-- Admin bewusst entscheidet, dass Teilbereiche dafuer sinnvoll sind.
-- ============================================================================

alter table offertentyp add column teilbereiche_moeglich boolean not null default false;

update offertentyp set teilbereiche_moeglich = true where berechnungsmodell = 'formel';
