-- Doku-Tools Etappe 2: Ablage im Google Drive.
-- google_verbindung: Refresh-Token pro Person, nur für die Edge Function doku-google (keine Policy = kein Browserzugriff).
create table if not exists google_verbindung (
  benutzer_id uuid primary key references benutzer(id) on delete cascade,
  refresh_token text not null,
  scope text,
  aktualisiert_am timestamptz not null default now()
);
alter table google_verbindung enable row level security;

-- Wo und mit welchem Stand ein Dokument im Drive liegt (drive_stand = Werte beim Ablegen → «geändert seit Ablage»)
alter table doku_dokument add column if not exists drive_datei_id text;
alter table doku_dokument add column if not exists drive_ordner_id text;
alter table doku_dokument add column if not exists drive_pfad text;
alter table doku_dokument add column if not exists drive_stand text;
alter table doku_dokument add column if not exists drive_abgelegt_am timestamptz;
