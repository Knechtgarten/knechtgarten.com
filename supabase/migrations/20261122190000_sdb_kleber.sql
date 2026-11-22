-- Sicherheitsdatenblatt-Kleber (gelbes P-touch-Band) für Produkte im Nachschlagewerk:
-- ufi = Nummer von der Produktetikette (fragt Tox Info Suisse am Telefon), sdb_code = geheimer Zufallscode für
-- die öffentliche Handy-Seite knechtgarten.com/s/<code> (Edge Function sdb-qr, ohne Anmeldung).
alter table public.wissen_eintrag add column if not exists ufi text;
alter table public.wissen_eintrag add column if not exists sdb_code text;
create unique index if not exists wissen_eintrag_sdb_code on public.wissen_eintrag (sdb_code) where sdb_code is not null;
select count(*) as spalten from information_schema.columns where table_name = 'wissen_eintrag' and column_name in ('ufi', 'sdb_code');
