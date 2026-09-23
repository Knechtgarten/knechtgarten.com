-- ============================================================================
-- Mail-Assistent: Nachbesserung der Ast/Zweig-Datenuebernahme aus der letzten
-- Migration. Zwei Faelle wurden 1:1 kopiert, ohne dass ihr altes Verhalten
-- mitkam - das haette sonst zwei echte Verschlechterungen verursacht:
--
-- 1) Zweige aus Unterkategorien mit Aktionstyp "Ruckfrage-Fenster" (der
--    Mitarbeiter waehlt heute schon manuell aus mehreren Antworten) haben
--    beim neuen Zweig faelschlich "entscheidung = 'ki'" bekommen - die KI
--    wuerde also plötzlich versuchen, das selbst zu entscheiden, statt dem
--    Mitarbeiter die Auswahl zu zeigen. Wird hier auf 'mitarbeiter' korrigiert.
--
-- 2) Der Zweig aus der alten Unterkategorie "Neuanfrage (Erstkontakt)"
--    (Aktionstyp "Kundenanfrage-Fenster", reiner Verweis, keine eigenen
--    Vorlagen) wuerde von der neuen Ast/Zweig-Logik als normaler, leerer
--    Zweig gelesen und dann faelschlich "KI schreibt frei" ausloesen, statt
--    weiterhin ueber die bestehende Kundenanfragen-Seite behandelt zu werden.
--    Diese Kopie wird entfernt (die urspruengliche Unterkategorie-Zeile
--    bleibt unangetastet erhalten) - bis "Kundenanfrage Erstkontakt" als
--    eigener Ast neu aufgebaut ist, laeuft dieser Fall weiterhin unveraendert
--    ueber die alte Kundenanfragen-Seite.
-- ============================================================================

update mailassistent_zweig z
set entscheidung = 'mitarbeiter'
from mailassistent_unterkategorie u
where z.id = u.id and u.aktionstyp = 'rueckfrage';

delete from mailassistent_zweig z
using mailassistent_unterkategorie u
where z.id = u.id and u.aktionstyp = 'kundenanfrage';
