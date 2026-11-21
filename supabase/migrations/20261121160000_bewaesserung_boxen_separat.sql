-- Bewässerung › Steuerung › Boxen: alle Boxen als eigene Offertenposition (bisher nur «S grau», Rest ging in «Material Steuerung»).
update auswahloption set ist_eigene_offertenposition = true
where id in ('00c93c26-bcb6-4092-b420-05f6fc0d401d', '5ec3d189-82b4-40ca-801a-d9c18fd40b87', '891da444-9511-4436-a327-d5255df2a3a2',
  '6b3b0dda-6900-4315-9385-cae0c40dee32', 'f3a36c0d-7f39-4e6f-9f15-24eee71dd4d9', '16f693bb-8154-46ae-89ad-ec286696b62b', 'be9a3513-ae76-4389-92b5-b5d46500434f');
select count(*) filter (where ist_eigene_offertenposition) separat, count(*) alle from auswahloption
where auswahlfeld_id = (select auswahlfeld_id from auswahloption where id = '8be2e83b-5e3b-422a-bf3b-0d3cc23d3786');
