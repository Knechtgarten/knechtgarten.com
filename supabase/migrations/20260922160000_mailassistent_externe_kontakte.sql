-- ============================================================================
-- Mail-Assistent: "Externe Kontakte & Firmen" - Teil des Nachschlagewerks.
-- Bekannte Lieferanten-/Architekten-/Partnerfirmen mit ihren Domains, damit
-- die KI bei der Personen-Rollen-Erkennung eine Domain direkt einer Firma
-- zuordnen kann, statt zu raten (siehe z.B. der Andrin/Aquasolar-Fall).
-- ============================================================================

create table if not exists mailassistent_externe_kontakte (
  id uuid primary key default gen_random_uuid(),
  firma text not null,
  domains text not null,
  rolle text,
  notiz text,
  reihenfolge integer not null default 0
);
