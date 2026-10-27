-- Pool/Wassergarten: Titel "Beckenkörper PP" -> "Beckenkörper PP und Edelstahl" (Teilschritt + Auswahlfeld), Tippfehler "Beckentarnsport" korrigiert.
update teilschritt set name = 'Beckenkörper PP und Edelstahl' where id = '7feca83a-3080-4429-9839-8d0fd63f4a92' and name = 'Beckenkörper PP';
update auswahlfeld set name = 'Beckenkörper PP und Edelstahl' where id = 'b41cfae6-5242-4406-862e-abb65be61dfa' and name = 'Beckenkörper PP';
update option_freitext_vorlage set bezeichnung = 'Beckentransport' where bezeichnung = 'Beckentarnsport';
