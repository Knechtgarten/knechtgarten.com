-- Haupttool «Bewilligungen»: Baugesuche vorbereiten und möglichst automatisieren.
-- Ein Gesuch gehört zu einem Kunden (und optional einem Projekt). Geodaten (Zone, Gewässerschutz …) werden
-- beim Anlegen über die Edge Function «geodaten» geholt und hier gespeichert.

create table if not exists bewilligung (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references kunde(id) on delete restrict,
  projekt_id uuid references projekt(id) on delete set null,
  projektleiter_id uuid references benutzer(id) on delete set null,   -- unterschreibt für Knechtgarten
  bauvorhaben text,                      -- z. B. «Neubau Aussenschwimmbad mit aussen aufgestellter Wärmepumpe»
  strasse text, plz text, ort text, gemeinde text,
  parzelle text, egrid text, flaeche_m2 numeric, e numeric, n numeric,
  geodaten jsonb not null default '{}',  -- Zone, Gewässerschutz, Grundwasser, Baugrund, Geometer, betroffene/nicht betroffene Themen
  abklaerung jsonb not null default '{}', -- pool, waermepumpe, terrain, naeherbaurecht, abbruch … (true/false)
  schritte jsonb not null default '{}',   -- { schritt_key: { erledigt: bool, am, von, notiz } }
  nachbarn jsonb not null default '[]',   -- [{ name, adresse, parzelle, naeherbaurecht: bool, abstaende: [{ bauteil, soll, ist }], unterschrieben: bool }]
  plaene jsonb not null default '[]',     -- eingesehene Pläne [{ titel, massstab, datum }]
  ebau_nr text,
  status text not null default 'vorbereitung',  -- 'vorbereitung' | 'eingereicht' | 'bewilligt' | 'abgelehnt' | 'zurueckgezogen'
  eingereicht_am date, bewilligt_am date,
  notiz text,
  erstellt_von uuid references benutzer(id), erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create index if not exists bewilligung_kunde on bewilligung(kunde_id);
alter table bewilligung enable row level security;
drop policy if exists bewilligung_lesen on bewilligung;
create policy bewilligung_lesen on bewilligung for select to authenticated using (ist_buero_oder_admin());
drop policy if exists bewilligung_schreiben on bewilligung;
create policy bewilligung_schreiben on bewilligung for all to authenticated using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- eingescannte Unterschriften (für Dokumente, die Knechtgarten unterschreibt)
alter table benutzer add column if not exists unterschrift_pfad text;
insert into storage.buckets (id, name, public) values ('unterschriften', 'unterschriften', false) on conflict (id) do nothing;
drop policy if exists unterschriften_lesen on storage.objects;
create policy unterschriften_lesen on storage.objects for select to authenticated using (bucket_id = 'unterschriften' and ist_buero_oder_admin());
drop policy if exists unterschriften_schreiben on storage.objects;
create policy unterschriften_schreiben on storage.objects for insert to authenticated with check (bucket_id = 'unterschriften' and ist_buero_oder_admin());
drop policy if exists unterschriften_ersetzen on storage.objects;
create policy unterschriften_ersetzen on storage.objects for update to authenticated using (bucket_id = 'unterschriften' and ist_buero_oder_admin());
