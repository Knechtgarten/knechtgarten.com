-- Doku-Tools: Datum, Zeit und Adresse im Brief fett und eine Stufe grösser (Klassen fb + fg),
-- versehentlich halb fettes «L<b>iegenschaft </b>» in der Helikopter-Vorlage zurück auf normal.
update doku_vorlage set html = replace(html, 'L<b>iegenschaft </b>', 'Liegenschaft ') where schluessel = 'helikopter';
update doku_vorlage set
  html = regexp_replace(html, '<span data-f="(datum|zeit|kunde_adresse)"( class="[^"]*")?></span>', '<span data-f="\1" class="fb fg"></span>', 'g'),
  geaendert_am = now()
where schluessel in ('helikopter', 'kran');
