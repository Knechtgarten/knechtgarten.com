-- Neue Ansicht Tool A: Zeilen per Ziehen sortieren (Reihenfolge pro Offerte) und Textzeilen als eigene Zeilen.
alter table public.offerte add column if not exists zeilen_reihenfolge jsonb;
comment on column public.offerte.zeilen_reihenfolge is 'Reihenfolge der Zeilen im Dokument (Liste von Zeilen-Schlüsseln), per Ziehen gesetzt';
alter table public.offerte_eigene_zeile
  add column if not exists schluessel text,
  add column if not exists typ text;
comment on column public.offerte_eigene_zeile.schluessel is 'Stabiler Schlüssel für die Reihenfolge (bleibt beim Speichern erhalten)';
comment on column public.offerte_eigene_zeile.typ is 'null = Position, text = Textzeile (zählt nicht, nicht im Easybill-Export)';
