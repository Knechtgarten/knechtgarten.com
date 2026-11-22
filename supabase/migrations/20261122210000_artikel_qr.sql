-- Artikel-Kleber fürs Lager: qr_code = geheimer Zufallscode für die öffentliche Handy-Seite knechtgarten.com/a/<code>
-- (Edge Function artikel-qr); wissen_eintrag_id = Produkt im Nachschlagewerk mit Sicherheitsdatenblatt (nur Verknüpfung,
-- das Datenblatt liegt beim Produkt). Später kommt auf derselben Seite «Nachbestellen» dazu, ohne neue Kleber.
alter table public.artikel add column if not exists qr_code text;
alter table public.artikel add column if not exists wissen_eintrag_id uuid references public.wissen_eintrag(id) on delete set null;
create unique index if not exists artikel_qr_code on public.artikel (qr_code) where qr_code is not null;
select count(*) as spalten from information_schema.columns where table_name = 'artikel' and column_name in ('qr_code', 'wissen_eintrag_id');
