-- ============================================================================
-- eval_ausdruck bekommt drei neue, einstellige Operatoren fuer Rundung:
-- 'ceil' (aufrunden), 'floor' (abrunden), 'round' (kaufmaennisch runden) -
-- jeweils genau ein Argument in node.args. Grund: der Formel-Baukasten
-- (Tool B) kennt bisher nur +,-,*,/ - fuer Faelle wie "Anzahl Stoesse =
-- AUFRUNDEN(Laenge / 4.8)" fehlte eine Rundungsmoeglichkeit. Wird zusammen
-- mit dem neuen Freitext-Formel-Modus (Formel als Text statt Baustein-Kette,
-- siehe tool-b-live-v1.html) eingefuehrt, gilt aber generell fuer jede
-- Formel im System (auch aus dem normalen Baukasten erzeugbar, falls dort
-- spaeter ein passender Baustein ergaenzt wird).
-- ============================================================================

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

    if op in ('ceil', 'floor', 'round') then
      teilergebnis := eval_ausdruck(node->'args'->0, werte);
      return case op
        when 'ceil' then ceil(teilergebnis)
        when 'floor' then floor(teilergebnis)
        when 'round' then round(teilergebnis)
      end;
    end if;

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
