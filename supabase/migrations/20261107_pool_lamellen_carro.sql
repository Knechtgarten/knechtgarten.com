-- Lamellenfarben wie bei Carro (Solar-Lamellen): Namen und Farbton für die Kacheln
update pool_katalog set name = 'Transparent Solar', farbe = '#5B6268' where kategorie = 'lamelle' and schluessel = 'transp';
update pool_katalog set name = 'Grau Solar',        farbe = '#7D8287' where kategorie = 'lamelle' and schluessel = 'grau';
update pool_katalog set name = 'Hellschwarz Solar', farbe = '#2E3236' where kategorie = 'lamelle' and schluessel = 'hschwarz';
update pool_katalog set name = 'Blau Solar',        farbe = '#2F5F96' where kategorie = 'lamelle' and schluessel = 'blau';
update pool_katalog set name = 'Bronze Solar',      farbe = '#6B4F38' where kategorie = 'lamelle' and schluessel = 'bronze';
update pool_katalog set name = 'Grün Solar',        farbe = '#3F6A3E' where kategorie = 'lamelle' and schluessel = 'gruen';
