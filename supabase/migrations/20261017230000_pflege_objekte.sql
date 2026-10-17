-- ============================================================================
-- Pflege-Tool: Objekte pro Kunde (z.B. Liegenschaften einer Verwaltung)
--
-- Ein Objekt = Strasse, PLZ, Ort + eigene Notiz, nur im Pflege-Tool erfasst.
-- Im Kunden-Detail waehlt man oben Hauptadresse oder ein Objekt; alles darunter
-- (Kategorien mit Angaben/Arbeiten/Zustaendig/Tabelle, Fotos, Angebote/Dokumente)
-- gehoert dann zu diesem Objekt. objekt_id null = Hauptadresse (Easybill-Adresse).
-- ============================================================================
create table pflege_objekt (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references pflege_kunde(kunde_id) on delete cascade,
  strasse text null,
  plz text null,
  ort text null,
  notiz text null,
  reihenfolge integer not null default 0,
  erstellt_am timestamptz not null default now()
);
create index pflege_objekt_kunde_idx on pflege_objekt (kunde_id, reihenfolge);
alter table pflege_objekt enable row level security;
create policy pflege_objekt_voller_zugriff on pflege_objekt
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Kategorien pro Objekt (eine Kategorie darf an Hauptadresse und an jedem Objekt einmal vorkommen)
alter table pflege_kunde_kategorie add column objekt_id uuid null references pflege_objekt(id) on delete cascade;
alter table pflege_kunde_kategorie drop constraint pflege_kunde_kategorie_kunde_id_kategorie_id_key;
create unique index pflege_kunde_kategorie_ort_uniq
  on pflege_kunde_kategorie (kunde_id, coalesce(objekt_id, '00000000-0000-0000-0000-000000000000'::uuid), kategorie_id);

-- Fotos und Angebote/Dokumente pro Objekt
alter table pflege_foto add column objekt_id uuid null references pflege_objekt(id) on delete cascade;
alter table pflege_dokument add column objekt_id uuid null references pflege_objekt(id) on delete cascade;
