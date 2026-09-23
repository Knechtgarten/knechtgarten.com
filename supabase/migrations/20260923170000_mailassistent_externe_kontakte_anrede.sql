-- Mail-Assistent: Externe Kontakte (Lieferanten/Architekten/Partnerfirmen)
-- koennen neu eine eigene Anrede hinterlegt bekommen (per Du/per Sie), die
-- den globalen Schreibstil-Standard fuer genau diese Firma uebersteuert -
-- z.B. Silvio Grütter von Grütter Metallwaren ist per Du, obwohl der
-- generelle Standard "Sie" ist. null = kein Override, es gilt der normale
-- Schreibstil.
alter table mailassistent_externe_kontakte add column if not exists anrede text;
