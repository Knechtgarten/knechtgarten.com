-- Werkzeuge › Pflege › Spritzmittel: Produktliste mit Dosierungen (pflegbar in der App).
-- dosierungen: [{ "n": "Standard", "menge": 15, "pro_l": 10 }]  = 15 (ml|g) auf 10 L Wasser
create table if not exists werkzeug_spritzmittel (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  hersteller text,
  art text,                              -- Insektizid, Fungizid, Dünger …
  einheit text not null default 'ml' check (einheit in ('ml', 'g')),
  dosierungen jsonb not null default '[]',
  bruehe_l_m2 numeric,                   -- L Brühe pro m² (aus Brühmenge l/ha des Herstellers)
  dichte numeric,                        -- g pro ml (für die Umrechnung g ↔ ml)
  hinweis text,
  quelle text,
  aktiv boolean not null default true,
  sortierung integer not null default 0,
  geaendert_am timestamptz not null default now()
);
alter table werkzeug_spritzmittel enable row level security;
drop policy if exists werkzeug_spritzmittel_lesen on werkzeug_spritzmittel;
drop policy if exists werkzeug_spritzmittel_pflegen on werkzeug_spritzmittel;
create policy werkzeug_spritzmittel_lesen on werkzeug_spritzmittel for select using (ist_eingeloggter_benutzer());
create policy werkzeug_spritzmittel_pflegen on werkzeug_spritzmittel for all
  using (recht_wert('werkzeuge', 'spritzmittel_pflegen', 'an') = 'J')
  with check (recht_wert('werkzeuge', 'spritzmittel_pflegen', 'an') = 'J');

-- Rechte: Rechner für alle, Produktliste pflegen für Büro + Vorarbeiter Pflege (Admin immer)
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'werkzeuge', 'pflege_spritz', 'an', 'J' from recht_gruppe g
on conflict do nothing;
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'werkzeuge', 'spritzmittel_pflegen', 'an', case when g.schluessel in ('buero', 'va_pflege') then 'J' else 'N' end from recht_gruppe g
on conflict do nothing;
