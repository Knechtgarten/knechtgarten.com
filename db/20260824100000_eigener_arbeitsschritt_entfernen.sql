-- ============================================================================
-- "Eigener Arbeitsschritt hinzufuegen" (dynamisch pro Offerte) wieder
-- entfernt - der Nutzer legt dafuer stattdessen bei Bedarf einen leeren
-- Arbeitsschritt direkt in der Vorlage an (z.B. "Eigene Arbeitsschritte")
-- und haengt eigene Teilschritte dort an. Eigene Teilschritte haengen darum
-- nur noch an einem echten Vorlagen-Arbeitsschritt.
-- ============================================================================

-- Sicherheitsnetz: falls doch schon ein Teilschritt ohne Vorlagen-
-- Arbeitsschritt erfasst wurde (ueber den jetzt entfernten Weg), muesste er
-- sonst die naechste Zeile (NOT NULL) verletzen - bislang keine echten
-- Offerten mit dieser Funktion, daher unkritisch.
delete from offerte_eigener_teilschritt where arbeitsschritt_id is null;

alter table offerte_eigener_teilschritt drop column eigener_arbeitsschritt_id cascade;
alter table offerte_eigener_teilschritt alter column arbeitsschritt_id set not null;

drop table offerte_eigener_arbeitsschritt;
