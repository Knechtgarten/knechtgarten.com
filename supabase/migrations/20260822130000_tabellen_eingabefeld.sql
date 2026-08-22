-- ============================================================================
-- "Tabellen-Eingabefeld": fuer wiederkehrende Zeilen (z.B. mehrere Troege),
-- deren Anzahl erst pro Offerte feststeht. Die Spalten (z.B. Menge/Flaeche/
-- Hoehe) werden einmal in Tool B festgelegt, die Zeilen selbst (Namen +
-- Werte) erfasst der Mitarbeiter direkt im Konfigurator (Tool A).
--
-- Eine Tabelle ist eine eingabefeld-Zeile mit ist_tabelle=true (analog zu
-- ist_titel) - dadurch haengt sie automatisch/kostenlos in derselben
-- Drag&Drop-Reihenfolge wie normale Eingabefelder und Zwischentitel.
--
-- Eine Spalte kann eine normale Zahlen-Eingabe sein ODER eine
-- "Berechnungsspalte" mit einer Formel (z.B. Flaeche x Hoehe), die denselben
-- Formel-Baukasten wie Terme/Ressourcenzeilen-Mengenformeln nutzt. Damit eine
-- Formel auch auf andere Spalten DERSELBEN Zeile verweisen kann, bekommt
-- eval_ausdruck einen dritten Referenztyp 'spalte' - inhaltlich identisch zu
-- 'eingabefeld' (Wert kommt immer aus der uebergebenen werte-Map, nie aus
-- einem DB-Lookup), nur der Name ist fuer Lesbarkeit getrennt.
-- ============================================================================

alter table eingabefeld add column ist_tabelle boolean not null default false;

create table eingabefeld_tabelle_spalte (
  id uuid primary key default gen_random_uuid(),
  eingabefeld_id uuid not null references eingabefeld(id) on delete cascade,
  name text not null,
  einheit text not null,
  reihenfolge integer not null default 0,
  ist_berechnung boolean not null default false,
  ausdruck jsonb null,
  zusatztext_moeglich boolean not null default false,
  flaechenformel_moeglich boolean not null default false,
  check (
    (ist_berechnung and ausdruck is not null) or
    (not ist_berechnung and ausdruck is null)
  )
);
alter table eingabefeld_tabelle_spalte enable row level security;
create policy eingabefeld_tabelle_spalte_voller_zugriff on eingabefeld_tabelle_spalte
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Die Zeilen selbst (z.B. "Trog 1") existieren nur pro Offerte, nicht in der
-- Vorlage - beliebig viele, frei benannt.
create table offerte_tabelle_zeile (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  eingabefeld_id uuid not null references eingabefeld(id) on delete restrict,
  name text not null,
  reihenfolge integer not null default 0
);
alter table offerte_tabelle_zeile enable row level security;
create policy offerte_tabelle_zeile_voller_zugriff on offerte_tabelle_zeile
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Nur fuer Eingabe-Spalten gespeichert (Berechnungsspalten werden immer live
-- ueber eval_ausdruck neu berechnet, wie alle anderen Formeln auch).
create table offerte_tabelle_wert (
  id uuid primary key default gen_random_uuid(),
  zeile_id uuid not null references offerte_tabelle_zeile(id) on delete cascade,
  spalte_id uuid not null references eingabefeld_tabelle_spalte(id) on delete restrict,
  wert numeric not null default 0,
  notiz text null,
  unique (zeile_id, spalte_id)
);
alter table offerte_tabelle_wert enable row level security;
create policy offerte_tabelle_wert_voller_zugriff on offerte_tabelle_wert
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

create or replace function eval_ausdruck(node jsonb, werte jsonb)
returns numeric
language plpgsql
as $$
declare
  ref_typ text;
  ref_id uuid;
  op text;
  arg jsonb;
  akkumulator numeric;
  teilergebnis numeric;
  term_row term%rowtype;
  i int;
begin
  if node ? 'lit' then
    return (node->>'lit')::numeric;
  end if;

  if node ? 'ref' then
    ref_typ := node->>'ref';
    ref_id := (node->>'id')::uuid;

    if ref_typ in ('eingabefeld', 'spalte') then
      if werte ? ref_id::text then
        return (werte->>ref_id::text)::numeric;
      else
        raise exception 'Kein Wert fuer % % uebergeben', ref_typ, ref_id;
      end if;

    elsif ref_typ = 'term' then
      select * into term_row from term where id = ref_id;
      if not found then
        raise exception 'Term % nicht gefunden', ref_id;
      end if;
      if term_row.typ = 'konstante' then
        return term_row.wert;
      elsif term_row.typ = 'systemwert' then
        if werte ? ref_id::text then
          return (werte->>ref_id::text)::numeric;
        else
          raise exception 'Kein Wert fuer Systemwert-Term % uebergeben', ref_id;
        end if;
      else
        return eval_ausdruck(term_row.ausdruck, werte);
      end if;

    else
      raise exception 'Unbekannter ref-Typ: %', ref_typ;
    end if;
  end if;

  if node ? 'op' then
    op := node->>'op';
    akkumulator := null;
    for i in 0 .. jsonb_array_length(node->'args') - 1 loop
      arg := node->'args'->i;
      teilergebnis := eval_ausdruck(arg, werte);
      if akkumulator is null then
        akkumulator := teilergebnis;
      else
        akkumulator := case op
          when '+' then akkumulator + teilergebnis
          when '-' then akkumulator - teilergebnis
          when '*' then akkumulator * teilergebnis
          when '/' then akkumulator / teilergebnis
          else null
        end;
      end if;
    end loop;
    return akkumulator;
  end if;

  raise exception 'Ungueltiger Ausdruck-Knoten: %', node;
end;
$$;
