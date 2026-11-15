-- Easybill-Angebote als Wissensquelle für die KI-Offerte: Positionen werden eingelesen (Funktion easybill-angebote-sync)
create table if not exists public.easybill_angebot_zeile (
  id bigserial primary key,
  document_id bigint not null,
  document_number text,
  document_date date,
  titel text,
  kunde text,
  position int not null,
  typ text,                 -- POSITION / POSITION_NOCALC
  bezeichnung text not null,
  menge numeric,
  einheit text,
  preis numeric,            -- CHF pro Einheit netto
  rabatt numeric,
  rabatt_typ text,
  mwst numeric,
  unique (document_id, position)
);
create index if not exists easybill_angebot_zeile_datum_idx on public.easybill_angebot_zeile(document_date desc);
create extension if not exists pg_trgm;
create index if not exists easybill_angebot_zeile_bez_trgm on public.easybill_angebot_zeile using gin (bezeichnung gin_trgm_ops);
alter table public.easybill_angebot_zeile enable row level security;
drop policy if exists easybill_angebot_zeile_lesen on public.easybill_angebot_zeile;
create policy easybill_angebot_zeile_lesen on public.easybill_angebot_zeile for select using (ist_eingeloggter_benutzer());

create table if not exists public.easybill_sync_status (
  schluessel text primary key,
  wert jsonb not null default '{}'::jsonb,
  geaendert_am timestamptz not null default now()
);
alter table public.easybill_sync_status enable row level security;
drop policy if exists easybill_sync_status_lesen on public.easybill_sync_status;
create policy easybill_sync_status_lesen on public.easybill_sync_status for select using (ist_eingeloggter_benutzer());

create or replace function public.ki_easybill_zeilen_suche(begriff text, anzahl int default 25)
returns table (angebot text, datum date, kunde text, titel text, bezeichnung text, menge numeric, einheit text, preis numeric, rabatt numeric, rabatt_typ text, mwst numeric)
language sql stable security definer set search_path = public as $$
  select document_number, document_date, kunde, titel, bezeichnung, menge, einheit, preis, rabatt, rabatt_typ, mwst
    from easybill_angebot_zeile
   where bezeichnung ilike '%' || begriff || '%'
   order by document_date desc nulls last
   limit greatest(1, least(anzahl, 50));
$$;
revoke all on function public.ki_easybill_zeilen_suche(text, int) from public, anon;
grant execute on function public.ki_easybill_zeilen_suche(text, int) to authenticated, service_role;
