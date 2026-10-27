-- Einsatzplaner: Auftrag unterbrechen
-- pausen  Unterbrüche als [von, bis) in Tagen ab Beginn des Auftrags (wandern beim Verschieben mit)
alter table planer_einsatz add column if not exists pausen jsonb not null default '[]'::jsonb;
