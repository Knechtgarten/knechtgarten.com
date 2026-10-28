-- Tagesrechner (Tool A): Anpassungen pro Teilschritt und Offerte (Detailfenster "Was ist drin?").
--  * ressourcenzeile_id gesetzt  = Vorlagenzeile angepasst (menge_pro_tag) oder in dieser Offerte weggelassen (geloescht)
--  * ressourcenzeile_id null     = in dieser Offerte ergaenzt (aus dem Artikelstamm mit artikel_id, oder eigene Position mit bezeichnung/einheit/preis)
-- Die Vorlage in Tool B bleibt unveraendert.
create table if not exists offerte_teilschritt_zeile (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  teilschritt_id uuid not null references teilschritt(id) on delete cascade,
  ressourcenzeile_id uuid references ressourcenzeile(id) on delete cascade,
  artikel_id uuid references artikel(id) on delete set null,
  kategorie text,
  bezeichnung text,
  einheit text,
  preis numeric,
  menge_pro_tag numeric,
  geloescht boolean not null default false,
  reihenfolge integer not null default 0
);
create index if not exists offerte_teilschritt_zeile_offerte on offerte_teilschritt_zeile (offerte_id);
alter table offerte_teilschritt_zeile enable row level security;
create policy offerte_teilschritt_zeile_voller_zugriff on offerte_teilschritt_zeile for all
  using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
