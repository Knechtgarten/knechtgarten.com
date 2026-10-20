-- ============================================================================
-- Einsatzplaner: Magazin (Arbeiten auf Vorrat) ersetzt die Auftraege-Spalte
--
-- planer_magazin  Arbeit auf Vorrat. Wer frueher fertig ist, nimmt sich eine.
--                 dauer kurz (bis 2 Std.) / mittel (1/2-1 Tag) / lang (> 1 Tag).
--                 Reihenfolge (sort) = Prioritaet, nur Buero sortiert.
--                 Einmalig: abhaken = erledigt_am gesetzt (verschwindet).
--                 Wiederkehrend: abhaken = zuletzt_am, rutscht ans Ende.
--                 liste = [{ "t": "...", "ok": false }, ...]
-- planer_datei    Fotos jetzt auch zu einer Magazin-Arbeit (magazin_id).
-- (planer_auftrag und Pendenzen Gruppe/Firma werden nicht mehr benutzt.)
-- ============================================================================

create table planer_magazin (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  dauer text not null default 'kurz' check (dauer in ('kurz', 'mittel', 'lang')),
  wiederkehrend boolean not null default false,
  sort double precision not null default 0,
  notiz text null,
  liste jsonb not null default '[]'::jsonb,
  zuletzt_am timestamptz null,
  zuletzt_von uuid null references benutzer(id) on delete set null on update cascade,
  erledigt_am timestamptz null,
  erledigt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);
create index planer_magazin_offen_idx on planer_magazin (dauer, sort) where erledigt_am is null;

alter table planer_magazin enable row level security;
create policy planer_magazin_lesen on planer_magazin for select using (ist_eingeloggter_benutzer());
create policy planer_magazin_erfassen on planer_magazin for insert with check (ist_eingeloggter_benutzer());
create policy planer_magazin_aendern on planer_magazin for update using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy planer_magazin_loeschen on planer_magazin for delete using (ist_buero_oder_admin());

-- Fotos: entweder zu einem Einsatz oder zu einer Magazin-Arbeit
alter table planer_datei alter column einsatz_id drop not null;
alter table planer_datei add column magazin_id uuid null references planer_magazin(id) on delete cascade;
alter table planer_datei add constraint planer_datei_ziel check ((einsatz_id is null) <> (magazin_id is null));
create index planer_datei_magazin_idx on planer_datei (magazin_id);
create policy planer_datei_magazin on planer_datei for all
  using (magazin_id is not null and ist_eingeloggter_benutzer())
  with check (magazin_id is not null and ist_eingeloggter_benutzer());

alter publication supabase_realtime add table planer_magazin;
