-- Teilschritt kann in Flaechentabellen (Tool A) als Auswahl im Dropdown
-- "Belag" angeboten werden (Tool B, Zahnrad beim Teilschritt: "Als Belag fuer
-- Flaechen anbieten"). Nur ein Kann, kein Muss - Standard ist aus.
alter table teilschritt add column ist_belag boolean not null default false;
