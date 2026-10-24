-- ============================================================================
-- Nachschlagewerk: statt Ein-/Ausblenden pro Kategorie nur noch, was beim Öffnen aufgeklappt ist.
-- offen_pc / offen_handy = aufgeklappte Abschnitte (null = Standard: PC Notizen + Technische Daten, Handy Notizen).
-- Leere Abschnitte rutschen im Tool automatisch nach unten. Service gibt es, sobald Service-Arbeiten erfasst sind:
-- mit_service ist dafür nicht mehr nötig und wird überall auf true gesetzt (normal_aus / qr_aus / mit_service bleiben ungenutzt stehen).
-- ============================================================================
alter table wissen_kategorie
  add column if not exists offen_pc text[],
  add column if not exists offen_handy text[];

update wissen_kategorie set mit_service = true where mit_service = false;
