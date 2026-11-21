-- Maschinen: zwei QR-Etiketten pro Stück (Sicherheit, Verwendung) mit geheimem Zufallscode.
-- Gelesen wird ohne Anmeldung nur über die Edge Function «maschine-qr» (prüft den Code, gibt nur diese eine Seite heraus).
-- Neuer Code = alter Kleber gilt nicht mehr.

create or replace function public.kg_zufallscode(n int default 16) returns text
language sql volatile as $$
  select string_agg(substr('abcdefghjkmnpqrstuvwxyz23456789', 1 + floor(random() * 31)::int, 1), '')
  from generate_series(1, n);
$$;

alter table public.wissen_exemplar
  add column if not exists qr_sicher text,
  add column if not exists qr_verw text;

update public.wissen_exemplar set qr_sicher = public.kg_zufallscode() where qr_sicher is null;
update public.wissen_exemplar set qr_verw = public.kg_zufallscode() where qr_verw is null;

alter table public.wissen_exemplar
  alter column qr_sicher set default public.kg_zufallscode(),
  alter column qr_verw set default public.kg_zufallscode();

create unique index if not exists wissen_exemplar_qr_sicher_key on public.wissen_exemplar (qr_sicher);
create unique index if not exists wissen_exemplar_qr_verw_key on public.wissen_exemplar (qr_verw);

select count(*) as stuecke, count(qr_sicher) as mit_code from public.wissen_exemplar;
