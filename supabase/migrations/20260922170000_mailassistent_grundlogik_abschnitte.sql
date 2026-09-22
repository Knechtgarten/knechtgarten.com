-- ============================================================================
-- Mail-Assistent: Grundlogik von einem einzelnen Textfeld auf mehrere frei
-- benannte, einzeln hinzufuegbare/loeschbare Abschnitte umgestellt - bessere
-- Uebersicht fuer Stefan. Ersetzt mailassistent_grundlogik_meta (bleibt in
-- der DB bestehen, wird aber vom Tool nicht mehr verwendet).
-- ============================================================================

create table if not exists mailassistent_grundlogik_abschnitt (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  inhalt text,
  reihenfolge integer not null default 0
);

insert into mailassistent_grundlogik_abschnitt (titel, inhalt, reihenfolge)
select 'Weiche zuerst',
  'Eingehend / Ausgehend / Kontaktanfrage - entspricht den drei Bereichen im Tool (Mailkategorien: Antwortmails / Mailkategorien: Erstmail / Kundenanfrage als Unterebene davon).',
  0
where not exists (select 1 from mailassistent_grundlogik_abschnitt);

insert into mailassistent_grundlogik_abschnitt (titel, inhalt, reihenfolge)
select 'Bewegungsreihenfolge',
  '1. Schreibstil + Faelle gelten immer, unabhaengig von der Kategorie.
2. Mail-Kategorie erkennen (Kategorie -> Unterkategorie -> Vorlage).
3. Bei Faktenfragen: Nachschlagewerk konsultieren (nur bei Bedarf, nicht automatisch bei jeder Anfrage).
4. Der Aktionstyp der gefundenen Kategorie/Vorlage bestimmt das weitere Vorgehen (direkter Entwurf, Kundenanfrage-Fenster oder Rueckfrage-Fenster).',
  1
where (select count(*) from mailassistent_grundlogik_abschnitt) = 1;
