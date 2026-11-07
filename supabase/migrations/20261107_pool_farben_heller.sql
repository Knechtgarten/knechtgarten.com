-- Beckenfarben im Plan heller: Schwarz = bisheriges Dunkelgrau, die anderen gleichmässig zwischen Weiss und Schwarz
update pool_katalog set farbe = '#D5D8DB', farbe2 = '#BDD6E2' where kategorie = 'farbe' and schluessel = 'hellgrau';
update pool_katalog set farbe = '#B7BCC1', farbe2 = '#ABC6D3' where kategorie = 'farbe' and schluessel = 'dunkelgrau';
update pool_katalog set farbe = '#9AA0A6', farbe2 = '#98B6C4' where kategorie = 'farbe' and schluessel = 'anthrazit';
update pool_katalog set farbe = '#7C848C', farbe2 = '#86A6B4' where kategorie = 'farbe' and schluessel = 'schwarz';
