-- Regenwassertank > Zusatzarbeiten: Bagger S/M/L als Optionsgruppe "Grabarbeiten und Leitungen" (ein Button mit Dropdown in Tool A)
do $$
declare g uuid := gen_random_uuid(); n int;
begin
  update auswahloption ao set optionsgruppe_id = g, optionsgruppe_name = 'Grabarbeiten und Leitungen'
   from auswahlfeld af, teilschritt ts, arbeitsschritt s
   where af.id = ao.auswahlfeld_id and ts.id = af.teilschritt_id and s.id = ts.arbeitsschritt_id
     and s.offertentyp_id = '35764680-9e7a-480a-b765-7a8fe488b054' and s.name = 'Zusatzarbeiten'
     and ao.name in ('Bagger S', 'Bagger M', 'Bagger L') and not ao.mehrfachauswahl;
  get diagnostics n = row_count;
  if n <> 3 then raise exception 'Erwartet 3 Optionen, gruppiert %', n; end if;
end $$;
