-- Vorauswahlen: benannte Buendel von Auswahloptionen pro (Formel-)Offertentyp,
-- die in Tool A mit einem Klick alle passenden Options-Buttons setzen. Ersetzt
-- das bisherige, verstreute "Standard-Option"-Haekchen (auswahloption.ist_standard)
-- - das wird in einer separaten, spaeteren Migration entfernt, sobald kein Code
-- mehr darauf zugreift.
create table vorauswahl (
  id uuid primary key default gen_random_uuid(),
  offertentyp_id uuid not null references offertentyp(id) on delete cascade,
  name text not null,
  ist_standard boolean not null default false,
  erstellt_am timestamptz not null default now()
);

-- Nur eine Standard-Vorauswahl je Offertentyp - wird automatisch bei einer
-- neuen Offerte uebernommen.
create unique index vorauswahl_ein_standard_je_typ on vorauswahl(offertentyp_id) where ist_standard;

create table vorauswahl_option (
  id uuid primary key default gen_random_uuid(),
  vorauswahl_id uuid not null references vorauswahl(id) on delete cascade,
  option_id uuid not null references auswahloption(id) on delete cascade,
  unique (vorauswahl_id, option_id)
);

alter table vorauswahl enable row level security;
create policy vorauswahl_lesen on vorauswahl for select using (ist_eingeloggter_benutzer());
create policy vorauswahl_admin_schreibt on vorauswahl for all using (ist_admin()) with check (ist_admin());

alter table vorauswahl_option enable row level security;
create policy vorauswahl_option_lesen on vorauswahl_option for select using (ist_eingeloggter_benutzer());
create policy vorauswahl_option_admin_schreibt on vorauswahl_option for all using (ist_admin()) with check (ist_admin());
