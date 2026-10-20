-- ============================================================================
-- Pflege-Tool: Kanaele der Voranmeldung (nur bei Abo mit Voranmeldung relevant)
-- Mehrere pro Kunde moeglich; leer = Kanal noch offen.
-- ============================================================================
alter table pflege_kunde add column voranmeldung_kanaele text[] not null default '{}'
  check (voranmeldung_kanaele <@ array['whatsapp', 'telefon', 'mail']::text[]);
