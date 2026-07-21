-- ============================================================================
-- Offertentool 2027 - Systemwert-Terms: dritter Term-Typ neben Konstante/Formel.
--
-- Anwendungsfall: Fahrzeit/Fahrstrecke einer EINFACHEN Fahrt (nicht Hin+Rueck)
-- eines einzelnen Lieferwagen-Transports, z.B. fuer eine Kiestransport-
-- Ressourcenzeile mit der Menge-Formel "Fahrzeit einfache Fahrt * 2 * Anzahl
-- Fahrten" (falls Hin+Rueck noetig ist, wird das *2 direkt in der Formel
-- ergaenzt - der Systemwert selbst bleibt bewusst die einfache Fahrt). Im
-- Unterschied zur bestehenden Lieferwagenfahrzeit-Konfiguration (die einmal
-- pro ganzem Bauteil rechnet) soll dieser Wert innerhalb einer normalen
-- Menge-Formel wie ein Term auswaehlbar sein.
--
-- Ein Systemwert-Term hat keinen gespeicherten Wert/keine Formel - der Wert wird
-- in Tool A zur Rechenzeit live ermittelt (Google Distance Matrix ab Kunde-PLZ,
-- gleiche Quelle wie die bestehende Lieferwagenfahrzeit-Berechnung) und ueber die
-- "werte"-Map an eval_ausdruck uebergeben, keyed nach der Term-Id - genau wie
-- Eingabefeld-Werte das schon tun.
-- ============================================================================

alter table term add column systemwert_key text null
  check (systemwert_key in ('fahrzeit_einfach_std', 'distanz_einfach_km'));

-- Alte Check-Constraints dynamisch entfernen (Namen koennen variieren) und mit
-- der neuen systemwert-Variante neu anlegen.
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'term'::regclass and contype = 'c'
  loop
    execute format('alter table term drop constraint %I;', c.conname);
  end loop;
end $$;

alter table term add constraint term_typ_check check (typ in ('formel', 'konstante', 'systemwert'));
alter table term add constraint term_felder_check check (
  (typ = 'konstante' and wert is not null and ausdruck is null and systemwert_key is null) or
  (typ = 'formel' and ausdruck is not null and wert is null and systemwert_key is null) or
  (typ = 'systemwert' and systemwert_key is not null and wert is null and ausdruck is null)
);

-- ----------------------------------------------------------------------------
-- eval_ausdruck: neuer Zweig fuer typ='systemwert' - Wert kommt (wie bei
-- Eingabefeldern) aus der uebergebenen "werte"-Map, keyed nach Term-Id, statt
-- aus term.wert/term.ausdruck.
-- ----------------------------------------------------------------------------
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

    if ref_typ = 'eingabefeld' then
      if werte ? ref_id::text then
        return (werte->>ref_id::text)::numeric;
      else
        raise exception 'Kein Wert fuer Eingabefeld % uebergeben', ref_id;
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
