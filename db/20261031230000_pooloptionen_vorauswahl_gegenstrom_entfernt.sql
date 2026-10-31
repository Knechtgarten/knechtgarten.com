-- Pooloptionen: Vorauswahl "Gegenstromanlage Standard" wieder entfernt (Nutzerentscheid: Button nicht gewünscht).
do $$
declare n int;
begin
  delete from vorauswahl where name = 'Gegenstromanlage Standard'
    and offertentyp_id = (select id from offertentyp where name = 'Pooloptionen' and papierkorb_am is null);
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Erwartet 1 Vorauswahl, gelöscht %', n; end if;
end $$;
