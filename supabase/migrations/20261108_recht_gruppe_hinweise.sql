-- Verwaltung › Gruppen & Rechte: kurzer Hinweis pro Tool und Gruppe (z. B. «darf Offerten ansehen, Preise fragt er im Büro»)
alter table recht_gruppe add column if not exists tool_hinweise jsonb not null default '{}'::jsonb;
