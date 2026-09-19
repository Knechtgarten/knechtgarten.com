-- Auswahlgruppen: Label -> Artikel (z.B. Farben), fuer Optionen mit einem
-- Dropdown statt einzelner Buttons pro Variante (z.B. "Poolabdeckungsfarben").
-- Gleiches Grundmuster wie staffelgruppe/staffelstufe, nur ohne Von/Bis-
-- Mengenbereich - stattdessen ein frei benennbares Label pro Wahlmoeglichkeit.
create table auswahlgruppe (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  titel text null,
  kategorie text null check (kategorie in ('personal','maschine','logistik','material')),
  erstellt_am timestamptz not null default now()
);

create table auswahlgruppe_option (
  id uuid primary key default gen_random_uuid(),
  auswahlgruppe_id uuid not null references auswahlgruppe(id) on delete cascade,
  label text not null,
  artikel_id uuid not null references artikel(id) on delete restrict,
  reihenfolge int not null default 0
);

alter table auswahlgruppe enable row level security;
create policy auswahlgruppe_lesen on auswahlgruppe for select using (ist_eingeloggter_benutzer());
create policy auswahlgruppe_admin_schreibt on auswahlgruppe for all using (ist_admin()) with check (ist_admin());

alter table auswahlgruppe_option enable row level security;
create policy auswahlgruppe_option_lesen on auswahlgruppe_option for select using (ist_eingeloggter_benutzer());
create policy auswahlgruppe_option_admin_schreibt on auswahlgruppe_option for all using (ist_admin()) with check (ist_admin());

-- Eine Option (Tool B) kann auf eine Auswahlgruppe verweisen - erscheint dann
-- in Tool A als Dropdown statt der Mengenoption-Zahl (oder zusaetzlich dazu).
alter table auswahloption add column auswahlgruppe_id uuid null references auswahlgruppe(id) on delete restrict;

-- Die automatisch erzeugte Ressourcenzeile unter einer solchen Option (siehe
-- Tool B syncAuswahlgruppenZeile()) verweist auf dieselbe Auswahlgruppe -
-- gleiches Feld-Muster wie staffelgruppe_id/zonengruppe_id/sonderposition_typ_id.
alter table ressourcenzeile add column auswahlgruppe_id uuid null references auswahlgruppe(id) on delete restrict;

-- Pro Offerte und Option: welche Auswahlgruppen-Option (z.B. welche Farbe)
-- wurde gewaehlt - parallel zu "anzahl" (Mengenoption).
alter table offerte_auswahl add column auswahlgruppe_option_id uuid null references auswahlgruppe_option(id) on delete set null;
