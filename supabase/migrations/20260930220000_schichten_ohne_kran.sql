-- Schichten (300-500 L): nur Maschine M und L, kein Kran.
do $$
declare ids uuid[];
begin
  select array_agg(o.id) into ids from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id
   where f.name = 'Natursteinmauer Plasselb' and o.name in ('Schichten Kran -20m', 'Schichten Kran -30m', 'Schichten Kran -45m');
  if ids is null or array_length(ids, 1) <> 3 then raise exception 'Erwartet 3 Optionen, gefunden %', coalesce(array_length(ids, 1), 0); end if;
  delete from ressourcenzeile where option_id = any(ids);
  delete from auswahloption where id = any(ids);
end $$;
