-- ============================================================================
-- Offertentool 2027 - Automatische Offertnummer pro Offertentyp/Jahr.
--
-- Format: {Jahr}-{Typcode}{laufende Nummer, 4-stellig} z.B. 2026-010001
-- Typcode: 01 = Mengenberechnung (formel), 02 = Tagesberechnung (tagessatz),
-- 03 = Artikelbasiert (artikel). Zaehlung startet pro Jahr und Typ neu bei 1.
--
-- naechste_offertnummer() ist SECURITY DEFINER, damit der Zaehler-Tabelle
-- kein direkter Zugriff (auch nicht lesend) noetig ist - die Nummer wird
-- ausschliesslich atomar ueber diese Funktion vergeben (INSERT ... ON
-- CONFLICT ... DO UPDATE auf derselben Zeile ist in Postgres serialisiert,
-- daher keine Race-Condition bei gleichzeitiger Offertenanlage).
-- ============================================================================

alter table offerte add column offertnummer text unique null;

create table offertnummer_zaehler (
  jahr int not null,
  typcode text not null,
  naechste_nummer int not null default 1,
  primary key (jahr, typcode)
);

alter table offertnummer_zaehler enable row level security;
create policy offertnummer_zaehler_kein_direktzugriff on offertnummer_zaehler
  for all using (false) with check (false);

create or replace function naechste_offertnummer(p_jahr int, p_typcode text)
returns int
language plpgsql
security definer
as $$
declare
  v_nummer int;
begin
  if not ist_eingeloggter_benutzer() then
    raise exception 'Nicht angemeldet.';
  end if;
  insert into offertnummer_zaehler (jahr, typcode, naechste_nummer)
  values (p_jahr, p_typcode, 2)
  on conflict (jahr, typcode)
  do update set naechste_nummer = offertnummer_zaehler.naechste_nummer + 1
  returning naechste_nummer - 1 into v_nummer;
  return v_nummer;
end;
$$;

grant execute on function naechste_offertnummer(int, text) to authenticated;
