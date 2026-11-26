-- Nachschlagewerk: Kacheln pro Eintrag ausblenden (Auge im Kachel-Balken).
-- Liste der Kachel-Schlüssel, z. B. {steck,sicher,anw}. Inhalt bleibt gespeichert, nur nicht angezeigt.
alter table public.wissen_eintrag add column if not exists ausgeblendet text[] not null default '{}';
