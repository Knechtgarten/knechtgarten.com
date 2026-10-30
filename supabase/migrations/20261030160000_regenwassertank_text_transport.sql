-- Regenwassertank: Offertentext aller 18 Tank-Optionen um "Transport" ergaenzt
do $$
declare n int;
begin
  update auswahloption set beschreibung = replace(beschreibung, 'Inkl. Aushub und Entsorgung', 'Inkl. Transport, Aushub und Entsorgung')
   where auswahlfeld_id = 'a261ca94-c416-4148-bd2c-fecbe2aaf8cb' and beschreibung like '%Inkl. Aushub und Entsorgung%';
  get diagnostics n = row_count;
  if n <> 18 then raise exception 'Erwartet 18 Optionen, geaendert %', n; end if;
end $$;
