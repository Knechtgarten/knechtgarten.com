-- Schichten (300-500 L) sind zu schwer für Handarbeit und kleinen Bagger: nur Maschine M/L (und Kran).
do $$
declare ids uuid[];
begin
  select array_agg(o.id) into ids from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id
   where f.name = 'Natursteinmauer Plasselb' and o.name in ('Schichten von Hand', 'Schichten Maschine S');
  if ids is null or array_length(ids, 1) <> 2 then raise exception 'Erwartet 2 Optionen, gefunden %', coalesce(array_length(ids, 1), 0); end if;
  delete from ressourcenzeile where option_id = any(ids);
  delete from auswahloption where id = any(ids);
end $$;
