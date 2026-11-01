-- Offerten-Übersicht: «nur eigene Offerten». Neue Offerten merken sich, wer sie erstellt hat
-- (auth.uid() als Default, gilt auch fürs Kopieren). Alte Offerten bleiben leer (Ersteller unbekannt)
-- und erscheinen nur unter «Alle». Die Wahl Alle/Eigene wird pro Benutzer gespeichert.
alter table offerte add column if not exists erstellt_von uuid default auth.uid() references benutzer(id) on delete set null;
create index if not exists offerte_erstellt_von_idx on offerte (erstellt_von);

alter table benutzer_startseite_einstellung add column if not exists offerten_nur_eigene boolean not null default false;
