-- ============================================================================
-- Personen-Stammblatt (Verwaltung): Personalien direkt bei benutzer.
-- Lesen/Schreiben wie benutzer: nur Admin bzw. die Person ihre eigene Zeile (bestehende Policies).
-- ============================================================================
alter table benutzer add column if not exists strasse text;
alter table benutzer add column if not exists plz_ort text;
alter table benutzer add column if not exists telefon text;
alter table benutzer add column if not exists geburtsdatum date;
alter table benutzer add column if not exists eintritt date;
alter table benutzer add column if not exists pensum text;
alter table benutzer add column if not exists notfallkontakt text;
alter table benutzer add column if not exists notizen text;
