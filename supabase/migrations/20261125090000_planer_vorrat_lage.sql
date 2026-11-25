-- Vorrat: Lage merken, wenn man einen Eintrag mit der Maus an eine Stelle aufzieht
-- zeile = Zeile im Vorrat (0 = oberste), start = Arbeitstag ab Woche 1 (0 = Mo Woche 1); leer = automatisch einreihen
alter table planer_vorrat add column if not exists zeile int, add column if not exists start numeric;
