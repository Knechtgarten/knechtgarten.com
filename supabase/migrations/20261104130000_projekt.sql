-- Projekte (Kontakte › Projekte): Ablauf von der Zusage bis zur Zahlung, pro Kunde.
-- Startet beim «Zugesagt» im Offerten-Board (Pendenz) oder von Hand in Kontakte.
-- schritte (jsonb) hält pro Schritt den Stand und das Datum, an dem geklickt wurde:
--   ab {stufe 0|1|2, am1, am2} · bb {keine, punkte{key: datum}, nachtraege [datum], erhalten, kosten} · avor {punkte{key: datum}}
--   va {am} · ak [datum, …] · sr {stufe 0|1|2, am1, am2} · zahlung {stand offen|bezahlt|m1|m2, am}
-- Die Fristen (gelb/orange/rot) rechnet die Seite aus zugesagt_am, baustart und den Daten der vorherigen Schritte.

create table if not exists projekt (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references kunde(id) on delete cascade,
  titel text,
  projektleiter_id uuid references benutzer(id) on delete set null,
  pendenz_id uuid references pendenz(id) on delete set null,
  zugesagt_am date not null default current_date,
  baustart date,                                   -- ungefährer Baustart (in der AVOR eingetragen)
  schritte jsonb not null default '{}'::jsonb,
  notiz text,
  archiviert_am timestamptz,
  erstellt_von uuid references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now()
);
create index if not exists projekt_kunde on projekt (kunde_id);
alter table projekt enable row level security;
drop policy if exists projekt_voll on projekt;
create policy projekt_voll on projekt for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Einstellungen (eine Zeile): Checklisten von AVOR und Baubewilligung, Fristen in Tagen
create table if not exists projekt_einstellung (
  id smallint primary key default 1 check (id = 1),
  checklisten jsonb not null,
  fristen jsonb not null,
  geaendert_am timestamptz not null default now()
);
alter table projekt_einstellung enable row level security;
drop policy if exists projekt_einstellung_voll on projekt_einstellung;
create policy projekt_einstellung_voll on projekt_einstellung for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

insert into projekt_einstellung (id, checklisten, fristen) values (1,
  '{"bb":[{"k":"auftrag","t":"Auftrag für Baubewilligung vom Kunden"},{"k":"planung","t":"Planungskosten verrechnet"},{"k":"fertig","t":"Gesuch fertiggestellt"},{"k":"unterschrift","t":"An den Kunden zur Unterschrift"},{"k":"eingereicht","t":"Bei der Gemeinde eingereicht"}],
    "avor":[{"k":"material","t":"Material bestellt"},{"k":"sub","t":"Subunternehmer bestellt"},{"k":"kunde","t":"Kunde über Termin informiert"},{"k":"leitungen","t":"Leitungspläne geprüft"},{"k":"maschinen","t":"Maschinen und Mulden reserviert"}]}',
  '{"ab":5,"bb":15,"avor_ohne_baustart":30,"avor_vor_baustart":10,"va_vor_baustart":5,"ak1_nach_va":5,"ak_intervall":14,"zahlung":30,"gelb":3,"rot":7}')
on conflict (id) do nothing;
