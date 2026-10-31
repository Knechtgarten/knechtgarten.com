-- Pendenzen: jede Liste gehoert fest in ihren Bereich (Zeitlisten links, Team-box + Besprechen rechts, Arten Mitte)
update pendenz_liste set bereich = case
  when zeit is not null then 'zeit'
  when art_id in ('team', 'besprechen') then 'team'
  else 'mitte' end
where bereich is distinct from case
  when zeit is not null then 'zeit'
  when art_id in ('team', 'besprechen') then 'team'
  else 'mitte' end;
