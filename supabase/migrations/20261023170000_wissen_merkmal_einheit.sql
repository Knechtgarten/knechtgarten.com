-- ============================================================================
-- Wissen & Geräte: keine eigene «Verwaltung» mehr (Angaben zum Exemplar genügen),
-- Merkmal-Vorschläge ohne «Gehört zu», dafür mit optionaler Einheit (kg, m, kW …).
-- ============================================================================
begin;

-- bisherige Verwaltungs-Angaben (Kaufpreis, Kasko …) zu den Angaben des Exemplars
update wissen_exemplar
set steckbrief = steckbrief || verwaltung, verwaltung = '[]'
where verwaltung <> '[]'::jsonb;

alter table wissen_merkmal drop constraint if exists wissen_merkmal_ziel_check;
alter table wissen_merkmal drop column if exists ziel;
alter table wissen_merkmal add column if not exists einheit text null;

update wissen_merkmal set einheit = v.einheit
from (values ('Gewicht', 'kg'), ('Breite', 'm'), ('Höhe', 'm'), ('Länge', 'm'), ('Leistung', 'kW'),
             ('Nutzlast', 'kg'), ('Anhängelast', 'kg'), ('Arbeitsbreite', 'cm'),
             ('Verarbeitungszeit', 'Min.'), ('Aushärtezeit', 'Std.'), ('Temperaturbereich', '°C')) v(name, einheit)
where wissen_merkmal.name = v.name and wissen_merkmal.einheit is null;

-- Verwaltungs-Merkmale bleiben als normale Vorschläge (Versicherung / LSVA, Kaskoschutz, Selbstbehalt, Kaufpreis)
comment on column wissen_exemplar.verwaltung is 'nicht mehr verwendet (seit 2026-10-23 alles in steckbrief)';

commit;
