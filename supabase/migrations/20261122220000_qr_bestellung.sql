-- QR-Bestellung: Artikel per Kleber-Scan bestellen (Vormerkung), im Büro über die Browser-Erweiterung in den Shop-Warenkorb legen.
-- Nur Lieferanten mit angebundenem Shop (bestell_anbindung.aktiv). Status: offen → warenkorb → bestellt → geliefert.

-- Anbindung pro Lieferant: Ablauf steckt in der Erweiterung (pro Shop-System), was sich ändern kann, steht hier.
create table if not exists public.bestell_anbindung (
  lieferant_id uuid primary key references public.lieferant(id) on delete cascade,
  plattform text not null check (plattform in ('magento')),
  shop_url text not null,                                   -- z. B. https://shop.aquasolar.ch
  sprache text not null default 'de',                       -- Pfad-Teil /de/
  bestaetigung text not null default '/checkout/onepage/success',  -- Teil der Adresse der Bestätigungsseite nach dem Abschicken
  aktiv boolean not null default true,
  beschrieb text,
  zuletzt_ok timestamptz,
  zuletzt_fehler text,
  aktualisiert_am timestamptz not null default now()
);
alter table public.bestell_anbindung enable row level security;
drop policy if exists bestell_anbindung_lesen on public.bestell_anbindung;
create policy bestell_anbindung_lesen on public.bestell_anbindung for select using (public.ist_eingeloggter_benutzer());
drop policy if exists bestell_anbindung_admin on public.bestell_anbindung;
create policy bestell_anbindung_admin on public.bestell_anbindung for all using (public.ist_admin()) with check (public.ist_admin());
-- «zuletzt ok / Fehler» darf auch das Büro schreiben (beim Übertragen)
drop policy if exists bestell_anbindung_status on public.bestell_anbindung;
create policy bestell_anbindung_status on public.bestell_anbindung for update using (public.ist_buero_oder_admin()) with check (public.ist_buero_oder_admin());

create table if not exists public.bestell_position (
  id uuid primary key default gen_random_uuid(),
  artikel_id uuid not null references public.artikel(id) on delete cascade,
  lieferant_id uuid references public.lieferant(id),
  menge numeric not null check (menge > 0),
  notiz text,
  status text not null default 'offen' check (status in ('offen', 'warenkorb', 'bestellt', 'geliefert')),
  erstellt_von uuid not null default auth.uid(),
  erstellt_name text,
  erstellt_am timestamptz not null default now(),
  lauf uuid,                       -- gleiche Übertragung in den Warenkorb = eine Bestellung
  warenkorb_am timestamptz,
  bestellt_am timestamptz,
  bestellt_von uuid,
  geliefert_am timestamptz
);
create index if not exists bestell_position_status on public.bestell_position (status, lieferant_id);
alter table public.bestell_position enable row level security;
drop policy if exists bestell_position_lesen on public.bestell_position;
create policy bestell_position_lesen on public.bestell_position for select using (public.ist_eingeloggter_benutzer());
drop policy if exists bestell_position_neu on public.bestell_position;
create policy bestell_position_neu on public.bestell_position for insert
  with check (public.ist_eingeloggter_benutzer() and erstellt_von = auth.uid() and status = 'offen');
drop policy if exists bestell_position_aendern on public.bestell_position;
create policy bestell_position_aendern on public.bestell_position for update
  using (public.ist_buero_oder_admin() or (erstellt_von = auth.uid() and status = 'offen'))
  with check (public.ist_buero_oder_admin() or (erstellt_von = auth.uid() and status = 'offen'));
drop policy if exists bestell_position_loeschen on public.bestell_position;
create policy bestell_position_loeschen on public.bestell_position for delete
  using (public.ist_buero_oder_admin() or (erstellt_von = auth.uid() and status = 'offen'));

-- Lieferant aus dem Artikel, Name der Person; ohne angebundenen Shop kein Bestellen
create or replace function public.bestell_position_vorher() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select lieferant_id into new.lieferant_id from artikel where id = new.artikel_id;
  if not exists (select 1 from bestell_anbindung where lieferant_id = new.lieferant_id and aktiv) then
    raise exception 'Für diesen Lieferanten ist kein Shop angebunden.';
  end if;
  select coalesce(nullif(anzeigename, ''), email) into new.erstellt_name from benutzer where id = new.erstellt_von;
  return new;
end $$;
drop trigger if exists bestell_position_vorher on public.bestell_position;
create trigger bestell_position_vorher before insert on public.bestell_position for each row execute function public.bestell_position_vorher();

-- Punkt am Tool-Icon: nur für Zuständige (app_einstellung 'qr_bestellung' → {"zustaendig":[uuid,…]}) und nur wenn etwas offen ist
create or replace function public.qr_bestellung_punkt() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from app_einstellung where schluessel = 'qr_bestellung' and (wert::jsonb -> 'zustaendig') ? auth.uid()::text)
     and exists (select 1 from bestell_position where status = 'offen');
$$;
grant execute on function public.qr_bestellung_punkt() to authenticated;

-- Aquasolar: Magento-Shop (geprüft 2026-11-22: Artikelnummer = SKU im Shop)
insert into public.bestell_anbindung (lieferant_id, plattform, shop_url, sprache, beschrieb)
select id, 'magento', 'https://shop.aquasolar.ch', 'de',
  'Magento (Hyva). Die Erweiterung sucht die Artikelnummer im Shop (Produktsuche des Shops), legt die Menge über die normale Warenkorb-Funktion hinein und trägt unsere Notiz im Kommentarfeld der Position ein. Abschicken machst du selbst im Shop.'
from public.lieferant where name = 'Aquasolar' and archiviert_am is null
on conflict (lieferant_id) do nothing;

select (select count(*) from bestell_anbindung) anbindungen;
