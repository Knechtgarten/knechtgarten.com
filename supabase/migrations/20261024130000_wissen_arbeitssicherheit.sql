-- ============================================================================
-- Wissen & Geräte: Abschnitt «Arbeitssicherheit» pro Eintrag.
-- psa = nötige Schutzausrüstung (Schlüssel, z. B. 'brille', 'gehoer'), sicherheit_html = Verhaltensregeln,
-- Dateien mit bereich 'sicherheit' = Sicherheitsdatenblätter, SUVA-Merkblätter.
-- ============================================================================
alter table wissen_eintrag
  add column if not exists psa text[] not null default '{}',
  add column if not exists sicherheit_html text;

alter table wissen_datei drop constraint if exists wissen_datei_bereich_check;
alter table wissen_datei add constraint wissen_datei_bereich_check check (bereich in ('anwendung', 'notiz', 'dokument', 'sicherheit'));
