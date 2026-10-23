-- ============================================================================
-- Wissen & Geräte: pro Kategorie wählen, welche Abschnitte beim Scannen des
-- QR-Codes (Handy) erscheinen. null = alles (wie bisher).
-- Schlüssel: x_angaben, x_service, x_notizen (Exemplar) und notizen, steck,
-- anw, service, kontakte, docs (allgemein)
-- ============================================================================
alter table wissen_kategorie add column if not exists qr_abschnitte text[] null;
