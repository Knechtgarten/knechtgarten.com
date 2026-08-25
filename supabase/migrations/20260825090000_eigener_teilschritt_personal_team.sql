-- ============================================================================
-- "Eigener Teilschritt" (Tagesrechner): Personal wird standardmaessig nicht
-- mehr als Artikel mit Stunden erfasst, sondern ueber ein einziges
-- "Personal/Team"-Feld in Tagen - im Hintergrund werden Vorarbeiter und
-- Gartenarbeiter trotzdem einzeln gerechnet (siehe recalc() in
-- tool-a2-allgemein-live-v1.html), damit sie in der Offertensumme getrennt
-- erscheinen und der Pool/Normal-Umschalter korrekt greift.
--
-- personal_individuell erlaubt den selteneren Ausnahmefall, dass die
-- Standard-Teambesetzung (1 Vorarbeiter + 1 Gartenarbeiter) nicht passt -
-- dann wird Personal wie zuvor einzeln ueber Artikelzeilen erfasst und
-- personal_tage bleibt 0 (nie beides gleichzeitig, siehe UI-Logik).
-- ============================================================================

alter table offerte_eigener_teilschritt add column personal_tage numeric not null default 0;
alter table offerte_eigener_teilschritt add column personal_individuell boolean not null default false;
