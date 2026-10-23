-- ============================================================================
-- Wissen & Geräte: gespeicherte Listen (Reiter «Listen», ersetzt die feste Tabelle
-- «Fahrzeuge & Maschinen»). Alle sehen sie, das Büro erstellt und ändert sie.
--
-- filter  {"kats": [kategorie_id], "bers": [bereich_id], "art": "Geräteart", "q": "Stichwort"}
-- pro     'exemplar' = eine Zeile pro Gerät, 'eintrag' = eine Zeile pro Eintrag
-- spalten ["titel", "nummer", "m:Gewicht", "v:Kaufpreis", "svc_next" ...] in dieser Reihenfolge
-- ============================================================================
create table if not exists wissen_liste (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  filter jsonb not null default '{}',
  pro text not null default 'exemplar' check (pro in ('exemplar', 'eintrag')),
  spalten jsonb not null default '["titel"]',
  sortierung int not null default 0,
  erstellt_von uuid null references benutzer(id) on delete set null on update cascade,
  erstellt_am timestamptz not null default now()
);
alter table wissen_liste enable row level security;
drop policy if exists wissen_liste_lesen on wissen_liste;
drop policy if exists wissen_liste_buero on wissen_liste;
create policy wissen_liste_lesen on wissen_liste for select using (ist_eingeloggter_benutzer());
create policy wissen_liste_buero on wissen_liste for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- Startlisten (nur wenn noch keine Listen da sind)
insert into wissen_liste (name, filter, pro, spalten, sortierung)
select * from (values
  ('Fahrzeuge & Maschinen',
   jsonb_build_object('kats', coalesce((select jsonb_agg(id) from wissen_kategorie where name = 'Maschinen & Fahrzeuge'), '[]')),
   'exemplar',
   '["nummer", "titel", "m:Marke / Modell", "m:Hersteller / Modell", "m:Anschaffungsjahr", "zustaendig", "planer", "svc_next"]'::jsonb, 10),
  ('Kleingeräte Pflege',
   jsonb_build_object('kats', coalesce((select jsonb_agg(id) from wissen_kategorie where name = 'Geräte & Werkzeug'), '[]'),
                      'bers', coalesce((select jsonb_agg(id) from wissen_bereich where name = 'Pflege'), '[]')),
   'exemplar',
   '["nummer", "titel", "m:Hersteller / Modell", "zustaendig", "m:Anschaffungsjahr", "svc_next", "notiz"]'::jsonb, 20)
) v(name, filter, pro, spalten, sortierung)
where not exists (select 1 from wissen_liste);
