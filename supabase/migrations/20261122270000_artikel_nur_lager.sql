-- Lagerartikel: nur fürs Lager/QR-Bestellung, nicht in Offerten; im Artikelstamm standardmässig ausgeblendet.
alter table public.artikel add column if not exists nur_lager boolean not null default false;
create index if not exists artikel_nur_lager on public.artikel (nur_lager) where nur_lager;
select count(*) from public.artikel where nur_lager;
