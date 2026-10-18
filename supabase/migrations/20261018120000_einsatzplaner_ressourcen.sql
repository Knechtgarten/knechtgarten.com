-- ============================================================================
-- Einsatzplaner Etappe 2: Fahrzeuge, Maschinen, Anhaenger
--
-- planer_ressource          Stammdaten (Nummer + Name). Fahrzeug kann ein
--                           Stammfahrzeug einer Person sein (stamm_person_id):
--                           es faehrt automatisch mit, wann immer diese Person
--                           eine Baustelle hat.
-- planer_ressource_einsatz  Zuteilungen:
--   art 'zuteilung'  Maschine an Baustelle (einsatz_id; ohne Zeit = ganze
--                    Baustelle, wandert mit) oder Fahrzeug/Anhaenger an Person
--                    (person_id + beginn/ende)
--   art 'stamm_weg'  Stammfahrzeug fuer diese Zeit nicht beim Stamm-Fahrer
--                    (frei fuer andere)
-- Rechte: lesen alle Eingeloggten, schreiben Admin/Buero. Anhaenger darf jede
-- Person fuer die eigene Zeile reservieren.
-- ============================================================================

create table planer_ressource (
  id uuid primary key default gen_random_uuid(),
  typ text not null check (typ in ('fahrzeug', 'maschine', 'anhaenger')),
  nummer text null,
  name text not null,
  stamm_person_id uuid null references planer_person(id) on delete set null,
  sortierung int not null default 0,
  aktiv boolean not null default true,
  erstellt_am timestamptz not null default now()
);

create table planer_ressource_einsatz (
  id uuid primary key default gen_random_uuid(),
  ressource_id uuid not null references planer_ressource(id) on delete cascade,
  art text not null default 'zuteilung' check (art in ('zuteilung', 'stamm_weg')),
  einsatz_id uuid null references planer_einsatz(id) on delete cascade,
  person_id uuid null references planer_person(id) on delete cascade,
  beginn timestamptz null,
  ende timestamptz null,
  erstellt_am timestamptz not null default now(),
  check (einsatz_id is not null or (person_id is not null and beginn is not null and ende is not null)),
  check (beginn is null or ende > beginn)
);
create index planer_ressource_einsatz_res_idx on planer_ressource_einsatz (ressource_id);
create index planer_ressource_einsatz_einsatz_idx on planer_ressource_einsatz (einsatz_id);

alter table planer_ressource enable row level security;
alter table planer_ressource_einsatz enable row level security;
create policy planer_ressource_lesen on planer_ressource for select using (ist_eingeloggter_benutzer());
create policy planer_ressource_buero on planer_ressource for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
create policy planer_res_einsatz_lesen on planer_ressource_einsatz for select using (ist_eingeloggter_benutzer());
create policy planer_res_einsatz_buero on planer_ressource_einsatz for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
-- Anhaenger: eigene Zeile reservieren / wieder freigeben
create policy planer_res_einsatz_anhaenger on planer_ressource_einsatz for all
  using (person_id is not null and planer_darf_person(person_id)
         and exists (select 1 from planer_ressource r where r.id = ressource_id and r.typ = 'anhaenger'))
  with check (person_id is not null and planer_darf_person(person_id)
         and exists (select 1 from planer_ressource r where r.id = ressource_id and r.typ = 'anhaenger'));

alter publication supabase_realtime add table planer_ressource, planer_ressource_einsatz;
