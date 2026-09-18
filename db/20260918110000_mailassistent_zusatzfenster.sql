-- ============================================================================
-- Mail-Assistent: Zusatzfenster fuer Verfassen-Vorlagen (Typ "Tabelle").
--
-- Manche Vorlagen (z.B. Bestellungen) brauchen strukturierte Eingaben statt
-- freien Stichworten - eine Liste von Positionen (z.B. "Lampe Typ 1"..."Lampe
-- Typ 6") mit Anzahl und ein paar Zusatzspalten (z.B. Farbe, Erdspiess,
-- Kabellaenge), plus eine freie Zeile fuer nicht vorgesehene Positionen.
--
-- Ein Zusatzfenster gehoert zu genau einer Vorlage (1:1). Beim Ausfuellen in
-- Gmail wird daraus eine Liste gebaut und im "platzhalter"-Text der Vorlage
-- ersetzt - ganz ohne KI-Aufruf, da die Daten schon vollstaendig strukturiert
-- sind.
--
-- "typ" ist schon als Spalte vorgesehen fuer eine spaetere Kalender-Variante,
-- wird aber vorerst nur mit 'tabelle' befuellt.
-- ============================================================================

create table mailassistent_zusatzfenster (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null unique references mailassistent_vorlage(id) on delete cascade,
  typ text not null default 'tabelle' check (typ in ('tabelle','kalender')),
  titel text not null default '',
  platzhalter text not null default '[BESTELLLISTE]',
  erlaubt_eigene_eingabe boolean not null default true,
  erstellt_am timestamptz not null default now(),
  aktualisiert_am timestamptz not null default now()
);

create table mailassistent_zusatzfenster_spalte (
  id uuid primary key default gen_random_uuid(),
  zusatzfenster_id uuid not null references mailassistent_zusatzfenster(id) on delete cascade,
  titel text not null,
  reihenfolge int not null default 0
);

create table mailassistent_zusatzfenster_position (
  id uuid primary key default gen_random_uuid(),
  zusatzfenster_id uuid not null references mailassistent_zusatzfenster(id) on delete cascade,
  titel text not null,
  reihenfolge int not null default 0
);

do $$
declare
  t text;
begin
  foreach t in array array[
    'mailassistent_zusatzfenster','mailassistent_zusatzfenster_spalte','mailassistent_zusatzfenster_position'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_buero_admin on %I for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());', t, t);
  end loop;
end $$;
