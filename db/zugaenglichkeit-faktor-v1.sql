-- ============================================================================
-- Offertentool 2027 - Zugaenglichkeits-Faktor
-- Pro Ressourcenzeile ein Faktor je Zugaenglichkeits-Stufe (1=Komplex,
-- 2=Mittel 25-75m, 3=Kurz 10-25m, 4=Direkt 0-10m), Default 1.0 (= kein
-- Einfluss). Pro Teilbereich wird EINE Stufe gewaehlt (Default 2 = Mittel),
-- die dann alle aktiven Ressourcenzeilen dieses Teilbereichs mit ihrem
-- jeweils hinterlegten Faktor fuer genau diese Stufe multipliziert.
-- ============================================================================
alter table ressourcenzeile add column zugang_stufe1 numeric not null default 1;
alter table ressourcenzeile add column zugang_stufe2 numeric not null default 1;
alter table ressourcenzeile add column zugang_stufe3 numeric not null default 1;
alter table ressourcenzeile add column zugang_stufe4 numeric not null default 1;

alter table teilflaeche add column zugaenglichkeit_stufe integer not null default 2;
alter table teilflaeche add constraint teilflaeche_zugang_stufe_check check (zugaenglichkeit_stufe between 1 and 4);
