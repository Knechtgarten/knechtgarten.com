-- Neue Ansicht Tool A: Handänderungen merken sich den Tool-Wert beim Ändern (Basis) und die Einheit kann überschrieben werden.
alter table public.offerte_zeilen_korrektur
  add column if not exists basis_menge numeric,
  add column if not exists basis_preis numeric,
  add column if not exists einheit_korrektur text;
comment on column public.offerte_zeilen_korrektur.basis_menge is 'Tool-Menge zum Zeitpunkt der Handänderung bzw. des letzten «Behalten» (Popup bei Abweichung)';
comment on column public.offerte_zeilen_korrektur.basis_preis is 'Tool-Preis zum Zeitpunkt der Handänderung bzw. des letzten «Behalten»';
comment on column public.offerte_zeilen_korrektur.einheit_korrektur is 'Von Hand überschriebene Einheit (null = Einheit vom Tool)';
