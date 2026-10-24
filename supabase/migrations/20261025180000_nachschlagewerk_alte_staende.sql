-- Nachschlagewerk: ältere Zählerstände aus der Notiz des Stücks («km Januar 2025: …», «Betriebsstunden Nov. 2024: …»)
-- werden Zeilen «Stand» beim Service und aus der Notiz entfernt.
do $$
declare n record; l text; m text[]; rest text[]; d date; v text;
begin
  for n in select * from public.wissen_notiz where exemplar_id is not null and html ~* '(^|<br>)(km Januar|Betriebsstunden Nov\.) \d{4}: ' loop
    rest := '{}';
    foreach l in array regexp_split_to_array(n.html, '<br>') loop
      m := regexp_match(l, '^(km Januar|Betriebsstunden Nov\.) (\d{4}): (.+)$');
      if m is null then rest := rest || l; continue; end if;
      d := make_date(m[2]::int, case when m[1] like 'km%' then 1 else 11 end, 1);
      v := trim(m[3]); if v !~ '\s(h|km)$' then v := v || case when m[1] like 'km%' then ' km' else ' h' end; end if;
      insert into public.wissen_service_erledigt (eintrag_id, exemplar_id, service_id, arbeit, jahr, kw, erledigt, datum, stand)
        values (n.eintrag_id, n.exemplar_id, null, 'Stand', extract(isoyear from d)::int, extract(week from d)::int, true, d, v);
    end loop;
    update public.wissen_notiz set html = array_to_string(rest, '<br>') where id = n.id;
  end loop;
end $$;
