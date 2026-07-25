-- ============================================================================
-- Offertentool 2027 - Kies-Transport und Beton-Transport als zwei komplett
-- getrennte Kieswerk-Tabellen statt einer gemeinsamen.
--
-- Grund: Es sind zwei unabhaengige Sonderpositionen (mal wird Kies, mal Beton
-- gebraucht) - der Nutzer will das auch in der Datenpflege sauber getrennt
-- sehen, nicht als gemeinsame Zeile mit vier Preisfeldern.
-- ============================================================================

create table kieswerk_kies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null default '',
  pauschale numeric not null default 0,
  km_preis numeric not null default 0,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now()
);

create table kieswerk_beton (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null default '',
  pauschale numeric not null default 0,
  km_preis numeric not null default 0,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now()
);

do $$
declare
  t text;
begin
  foreach t in array array['kieswerk_kies','kieswerk_beton'] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_lesen on %I for select using (ist_eingeloggter_benutzer());', t, t);
    execute format('create policy %I_admin_schreibt on %I for all using (ist_admin()) with check (ist_admin());', t, t);
  end loop;
end $$;

-- Bestehende Daten aus der bisherigen kombinierten kieswerk-Tabelle uebernehmen.
insert into kieswerk_kies (name, adresse, pauschale, km_preis, reihenfolge, erstellt_am)
  select name, adresse, pauschale_kies, km_preis_kies, reihenfolge, erstellt_am from kieswerk;
insert into kieswerk_beton (name, adresse, pauschale, km_preis, reihenfolge, erstellt_am)
  select name, adresse, pauschale_beton, km_preis_beton, reihenfolge, erstellt_am from kieswerk;

drop table kieswerk;
