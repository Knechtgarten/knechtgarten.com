-- ============================================================================
-- Offerte -> Easybill-Angebot exportieren (schreibender Easybill-Zugriff,
-- bisher gab es nur die lesende Kundensuche). Haelt fest, ob/welches
-- Easybill-Dokument zu dieser Offerte gehoert - damit ein zweiter Klick auf
-- den Export-Button weiss, ob ein NEUES Angebot angelegt oder das bestehende
-- per PUT /documents/{id} ueberschrieben werden soll (siehe
-- easybill-offerte-export Edge Function).
--
-- easybill_document_id: die interne Easybill-ID (numerisch, fuer PUT/GET
-- gebraucht). easybill_document_number: die menschenlesbare Angebotsnummer
-- (z.B. "AN2026-0042") - rein zur Anzeige im Offertentool (Offerten-Liste +
-- einzelne Offerte), damit sichtbar ist, ob/als was diese Offerte in
-- Easybill existiert.
-- ============================================================================

alter table offerte add column easybill_document_id bigint null;
alter table offerte add column easybill_document_number text null;
alter table offerte add column easybill_exported_at timestamp with time zone null;
