-- MwSt-Sätze firmenweit (Verwaltung): Normal / Reduziert mit Gültig-ab (alte Offerten behalten den Satz an ihrem Offertdatum)
create table if not exists public.mwst_satz (
  id uuid primary key default gen_random_uuid(),
  art text not null check (art in ('normal','reduziert')),
  satz numeric not null,
  gueltig_ab date not null,
  erstellt_am timestamptz not null default now(),
  unique (art, gueltig_ab)
);
alter table public.mwst_satz enable row level security;
drop policy if exists mwst_satz_lesen on public.mwst_satz;
create policy mwst_satz_lesen on public.mwst_satz for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
insert into public.mwst_satz (art, satz, gueltig_ab) values ('normal', 8.1, '2024-01-01'), ('reduziert', 2.6, '2024-01-01') on conflict do nothing;

-- Artikel: Normal oder Reduziert (statt Zahl); Baumschule Däpp = reduziert
alter table public.artikel add column if not exists mwst_art text not null default 'normal' check (mwst_art in ('normal','reduziert'));
update public.artikel set mwst_art = 'reduziert' where lieferant_id in (select id from public.lieferant where name ilike 'Baumschule%d_e_pp%' or name ilike 'Baumschule D%pp%'); -- nur Baumschule Däpp (nicht Kieswerk Däpp)

-- Rabatt und MwSt pro Zeile in Offerten
alter table public.offerte_eigene_zeile add column if not exists rabatt numeric;
alter table public.offerte_eigene_zeile add column if not exists rabatt_art text check (rabatt_art in ('prozent','pauschal','einheit'));
alter table public.offerte_eigene_zeile add column if not exists mwst_art text check (mwst_art in ('normal','reduziert'));
alter table public.offerte_eigene_zeile add column if not exists artikel_id uuid references public.artikel(id) on delete set null;
alter table public.offerte_zeilen_korrektur add column if not exists rabatt numeric;
alter table public.offerte_zeilen_korrektur add column if not exists rabatt_art text check (rabatt_art in ('prozent','pauschal','einheit'));
alter table public.offerte_zeilen_korrektur add column if not exists mwst_art text check (mwst_art in ('normal','reduziert'));
