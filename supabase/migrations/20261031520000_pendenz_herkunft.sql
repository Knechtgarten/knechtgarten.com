-- Pendenzen: Herkunft für die Team-box – 'board' = von einem Kollegen im Tool zugeschoben,
-- 'mail' = per Mail an die Board-Adresse (kommt mit der Mail-Anbindung). null = selber erfasst.
alter table pendenz add column if not exists herkunft text null check (herkunft in ('board', 'mail'));
