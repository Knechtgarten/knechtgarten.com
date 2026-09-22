-- ============================================================================
-- Mail-Assistent: neue "Grundlogik"-Seite - reine Referenz/Dokumentation fuer
-- Stefan, wie die KI sich zwischen den Bereichen (Schreibstil/Faelle/
-- Mailkategorien/Nachschlagewerk/Aktionstyp) bewegt. Wird aktuell NICHT an
-- die KI mitgeschickt (die Reihenfolge steckt im Code-Ablauf selbst) -
-- rein informativ, editierbar wie Schreibstil.
-- ============================================================================

create table if not exists mailassistent_grundlogik_meta (
  id uuid primary key default gen_random_uuid(),
  inhalt text,
  version integer not null default 1,
  aktualisiert_am timestamptz,
  aktualisiert_von text
);

insert into mailassistent_grundlogik_meta (inhalt)
select 'WEICHE ZUERST
Eingehend / Ausgehend / Kontaktanfrage - entspricht den drei Bereichen im Tool (Mailkategorien: Antwortmails / Mailkategorien: Erstmail / Kundenanfrage als Unterebene davon).

BEWEGUNGSREIHENFOLGE
1. Schreibstil + Faelle gelten immer, unabhaengig von der Kategorie.
2. Mail-Kategorie erkennen (Kategorie -> Unterkategorie -> Vorlage).
3. Bei Faktenfragen: Nachschlagewerk konsultieren (nur bei Bedarf, nicht automatisch bei jeder Anfrage).
4. Der Aktionstyp der gefundenen Kategorie/Vorlage bestimmt das weitere Vorgehen (direkter Entwurf, Kundenanfrage-Fenster oder Rueckfrage-Fenster).'
where not exists (select 1 from mailassistent_grundlogik_meta);
