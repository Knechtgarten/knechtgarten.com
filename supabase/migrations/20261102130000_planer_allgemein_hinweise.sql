-- ============================================================================
-- Einsatzplaner: Allgemein nur noch zwei Zeilen – «Hinweise» (alle Icons: Arbeitsstart, Sitzung, Anlass,
-- Pneuwechsel, Lieferung) und «Maschinenservice». «Diverses» und «Liefertermine» werden ausgeblendet (aktiv = false),
-- ihre Icons wandern in «Hinweise» (früher «Anlässe / Betrieb»).
-- ============================================================================
update planer_markierung set person_id = 'e591ced9-de56-41da-afd8-2b81eab44c3a'
where person_id in ('bc7b708c-a40a-40ae-8a49-cfcbefd53053', '76f7ac8b-049c-45f3-89b2-26ee36929d06');

update planer_person set name = 'Hinweise' where id = 'e591ced9-de56-41da-afd8-2b81eab44c3a';
update planer_person set aktiv = false where id in ('bc7b708c-a40a-40ae-8a49-cfcbefd53053', '76f7ac8b-049c-45f3-89b2-26ee36929d06');
