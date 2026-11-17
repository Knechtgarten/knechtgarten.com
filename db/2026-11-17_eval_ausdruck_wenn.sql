-- Formeln: WENN(Bedingung; Dann; Sonst) und Vergleiche < <= > >= = <> (Stefan, 17.11.2026)
-- AST: {"op":"wenn","args":[Bedingung, Dann, Sonst]}, Bedingung z. B. {"op":">","args":[a,b]} → 1 (wahr) / 0 (falsch)
-- WENN rechnet nur den gewählten Zweig aus. Bestehende Formeln rechnen unverändert.
create or replace function public.eval_ausdruck(node jsonb, werte jsonb)
 returns numeric
 language plpgsql
as $function$
declare
  ref_typ text;
  ref_id uuid;
  op text;
  arg jsonb;
  akkumulator numeric;
  teilergebnis numeric;
  links numeric;
  rechts numeric;
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

    -- WENN(Bedingung; Dann; Sonst): Bedingung ungleich 0 = wahr
    if op = 'wenn' then
      teilergebnis := eval_ausdruck(node->'args'->0, werte);
      if coalesce(teilergebnis, 0) <> 0 then
        return eval_ausdruck(node->'args'->1, werte);
      else
        return eval_ausdruck(node->'args'->2, werte);
      end if;
    end if;

    -- Vergleiche: 1 = wahr, 0 = falsch
    if op in ('<', '<=', '>', '>=', '=', '<>') then
      links := eval_ausdruck(node->'args'->0, werte);
      rechts := eval_ausdruck(node->'args'->1, werte);
      return case op
        when '<'  then (links <  rechts)::int
        when '<=' then (links <= rechts)::int
        when '>'  then (links >  rechts)::int
        when '>=' then (links >= rechts)::int
        when '='  then (links =  rechts)::int
        when '<>' then (links <> rechts)::int
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
$function$;

-- Test: WENN(1.2 > 1; 0.5; 0.3) = 0.5, WENN(1 > 1; 0.5; 0.3) = 0.3, WENN(0.7 <= 1; 0.3; 0.5) = 0.3
select public.eval_ausdruck('{"op":"wenn","args":[{"op":">","args":[{"lit":1.2},{"lit":1}]},{"lit":0.5},{"lit":0.3}]}'::jsonb, '{}'::jsonb) a,
       public.eval_ausdruck('{"op":"wenn","args":[{"op":">","args":[{"lit":1},{"lit":1}]},{"lit":0.5},{"lit":0.3}]}'::jsonb, '{}'::jsonb) b,
       public.eval_ausdruck('{"op":"wenn","args":[{"op":"<=","args":[{"lit":0.7},{"lit":1}]},{"lit":0.3},{"lit":0.5}]}'::jsonb, '{}'::jsonb) c;
