-- Einsatzplaner: «allein» pro Halbtag statt für die ganze Baustelle
-- allein_tage  Halbtage (relativ zum ersten Halbtag der Baustelle), an denen allein arbeiten okay ist
--              → blauer Punkt; wandert beim Verschieben mit. Alte Baustellen mit allein = true gelten
--              bis zur ersten Änderung als «alle Tage allein».
alter table planer_einsatz add column if not exists allein_tage jsonb not null default '[]'::jsonb;
