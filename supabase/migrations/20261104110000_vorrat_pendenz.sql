-- Zugesagte Offerte (Pendenz im Offerten-Board) → Balken im Arbeitsvorrat des Planers.
-- planer_vorrat.pendenz_id: woher der Vorrat-Balken kommt.
-- pendenz.eingeplant_am: wann der Vorrat-Balken im Planer eingeplant wurde (Karte danach 14 Tage hell, dann Archiv).

alter table planer_vorrat add column if not exists pendenz_id uuid references pendenz(id) on delete set null;
create index if not exists planer_vorrat_pendenz on planer_vorrat (pendenz_id);
alter table pendenz add column if not exists eingeplant_am timestamptz;
