-- Bewässerung (Steuerung):
-- 1) Term «Total Gefässe Rund + Metall» zählte Metallgefässe doppelt und Gefässe rund gar nicht
update term
   set formel_baukasten_ausdruck = '{"op": "+", "args": [{"id": "a09d08f0-932b-482e-8728-0a2736ced3c2", "ref": "spalte"}, {"id": "60dd939f-e47c-478c-8f2b-6073a7831a96", "ref": "spalte"}]}'::jsonb,
       ausdruck                  = '{"op": "+", "args": [{"id": "a09d08f0-932b-482e-8728-0a2736ced3c2", "ref": "spalte"}, {"id": "60dd939f-e47c-478c-8f2b-6073a7831a96", "ref": "spalte"}]}'::jsonb
 where id = '02426c53-9dc1-4436-bdb1-895a2f407972';

-- 2) Boxen: jede Wandbox hatte die Zeile «Pauschale Hilfsmaterial» doppelt – je eine entfernen (keine Offerte verweist darauf)
delete from ressourcenzeile where id in (
  '7f22a5be-2abc-49ed-8122-9041a38ca87f',  -- Wandbox S grau
  'be86d339-06a5-495a-9f15-9ed835ec018f',  -- Wandbox S anthrazit
  'c8d2a83f-2678-485d-a5c7-fcdcc5d6568c',  -- Wandbox M grau
  'ac058393-78b2-4cab-bd13-f8557db138ea',  -- Wandbox M anthrazit
  '65182de7-a919-42f5-aa60-346c6d1382bf',  -- Wandbox L grau
  '8239891c-03a1-4f45-9b62-fe618295a52a'   -- Wandbox L anthrazit
) and not exists (select 1 from offerte_ressourcenzeile_korrektur k where k.ressourcenzeile_id = ressourcenzeile.id);
