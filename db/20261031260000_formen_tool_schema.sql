-- Formen-Tool (Naturteich/Schwimmteich): Schalter pro Offertentyp, Formdaten pro Offerte, fünf neue Systemwerte (Flächen/Umfänge aus dem Code).
alter table offertentyp add column if not exists formen_aktiv boolean not null default false;
alter table offerte add column if not exists formen_daten jsonb;

alter table term drop constraint if exists term_systemwert_key_check;
alter table term add constraint term_systemwert_key_check check (systemwert_key = any (array[
  'fahrzeit_einfach_std','distanz_einfach_km','distanz_naechstes_kieswerk_km','distanz_naechste_deponie_km','belag_flaeche','belag_flaeche_alle',
  'form_flaeche_teich','form_umfang_teich','form_flaeche_tief','form_umfang_tief','form_flaeche_rand'
]::text[]));
