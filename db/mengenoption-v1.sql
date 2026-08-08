-- ============================================================================
-- Offertentool 2027 - "Mengenoption": bei einer Auswahloption zusaetzlich zum
-- reinen Ja/Nein eine Anzahl eingeben koennen (z.B. "Poolskimmer einbauen" x
-- 2 Stueck) - die Anzahl multipliziert die Menge aller Ressourcenzeilen
-- dieser Option (genau wie die bestehende Teilflaechen-Menge tfMenge), wirkt
-- sich also automatisch korrekt auf Staffelstufen/Sonderpositionen aus, statt
-- z.B. einen Transport einfach nochmals komplett zu verdoppeln.
-- ============================================================================

alter table auswahloption add column mengenoption boolean not null default false;
alter table teilflaeche_auswahl add column anzahl numeric not null default 1;
