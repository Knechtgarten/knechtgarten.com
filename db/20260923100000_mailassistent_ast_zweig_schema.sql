-- ============================================================================
-- Mail-Assistent: Umbau von Kategorie/Unterkategorie/Aktionstyp auf das neue
-- Ast/Zweig-Modell (siehe Memory "mailassistent-wissensstruktur"). Fixe
-- Tiefe: Ast (Ebene 1) -> Zweig (Ebene 2) -> Vorlagen. Kein Datenverlust:
-- mailassistent_kategorie/mailassistent_unterkategorie und die alten Spalten
-- auf mailassistent_vorlage bleiben unangetastet stehen, nur ungenutzt - der
-- neue Code arbeitet ab jetzt ueber zweig_id statt kategorie_id/unterkategorie_id.
--
-- WICHTIG: "Kundenanfrage Erstkontakt" als eigener Ast mit den Zweigen
-- Absage/Kapazitaet/Termin trotz Distanz/Offerte anhand Fotos/Architekt
-- zu-/absagen wird HIER NICHT automatisch angelegt - das ist inhaltlich neue
-- Struktur (keine 1:1-Entsprechung in den bisherigen Daten) und wird von
-- Stefan im neuen Verwaltungstool selbst aufgebaut, bei Bedarf mit den alten
-- "kundenanfrage"-Vorlagen als Textvorlage zum Kopieren.
-- ============================================================================

-- 1) Neue Tabellen ------------------------------------------------------------
create table if not exists mailassistent_ast (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  anwenden_bei text,
  nicht_anwenden_bei text,
  reihenfolge int not null default 0,
  ast_funktion jsonb,
  erstellt_am timestamptz not null default now()
);

create table if not exists mailassistent_zweig (
  id uuid primary key default gen_random_uuid(),
  ast_id uuid not null references mailassistent_ast(id) on delete cascade,
  titel text not null,
  anwenden_bei text,
  nicht_anwenden_bei text,
  entscheidung text not null default 'ki' check (entscheidung in ('ki','mitarbeiter')),
  frage_ki text,
  frage_mitarbeiter text,
  zweig_funktion jsonb,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now()
);

-- 2) Neue Spalten auf Vorlage ---------------------------------------------
alter table mailassistent_vorlage add column if not exists zweig_id uuid references mailassistent_zweig(id) on delete set null;
alter table mailassistent_vorlage add column if not exists kurzbeschreibung text;
alter table mailassistent_vorlage add column if not exists verbindlichkeit text check (verbindlichkeit in ('haargenau','angepasst','hilfetext'));

-- 3) Partnerbetriebe an den Ast haengen (fuer die Distanzlogik-Ast-Funktion) --
alter table mailassistent_partnerbetrieb add column if not exists ast_id uuid references mailassistent_ast(id) on delete set null;

-- 4) Bestehende Kategorien 1:1 als Aeste uebernehmen (gleiche id, damit
--    bestehende Referenzen unten einfach weiterverwendet werden koennen) ----
insert into mailassistent_ast (id, titel, anwenden_bei, nicht_anwenden_bei, reihenfolge)
select id, titel, anwenden_bei, nicht_anwenden_bei, reihenfolge
from mailassistent_kategorie k
where not exists (select 1 from mailassistent_ast a where a.id = k.id);

-- 5) Bestehende Unterkategorien 1:1 als Zweige uebernehmen (gleiche id) ------
insert into mailassistent_zweig (id, ast_id, titel, anwenden_bei, nicht_anwenden_bei, reihenfolge)
select id, kategorie_id, titel, anwenden_bei, nicht_anwenden_bei, reihenfolge
from mailassistent_unterkategorie u
where not exists (select 1 from mailassistent_zweig z where z.id = u.id);

-- 6) Fuer jeden Ast mit noch direkt zugeordneten Vorlagen (kategorie_id
--    gesetzt, unterkategorie_id leer) einen Auffang-Zweig "Allgemein"
--    anlegen - im neuen Modell braucht jede Vorlage einen Zweig ------------
insert into mailassistent_zweig (ast_id, titel, anwenden_bei, nicht_anwenden_bei, reihenfolge)
select distinct k.id, 'Allgemein', k.anwenden_bei, k.nicht_anwenden_bei, 999
from mailassistent_kategorie k
join mailassistent_vorlage v on v.kategorie_id = k.id and v.unterkategorie_id is null and v.richtung = 'antworten'
where not exists (
  select 1 from mailassistent_zweig z where z.ast_id = k.id and z.titel = 'Allgemein'
);

-- 7) Vorlagen auf ihren Zweig umhaengen ---------------------------------------
update mailassistent_vorlage v
set zweig_id = v.unterkategorie_id
where v.richtung = 'antworten' and v.unterkategorie_id is not null and v.zweig_id is null;

update mailassistent_vorlage v
set zweig_id = z.id
from mailassistent_zweig z
where v.richtung = 'antworten' and v.unterkategorie_id is null and v.kategorie_id = z.ast_id
  and z.titel = 'Allgemein' and v.zweig_id is null;

-- 8) Kurzbeschreibung + Verbindlichkeit aus den alten Feldern uebernehmen ----
update mailassistent_vorlage
set kurzbeschreibung = coalesce(nullif(trim(wann_trifft_zu), ''), titel)
where richtung = 'antworten' and kurzbeschreibung is null;

update mailassistent_vorlage
set verbindlichkeit = case verbindlichkeitsgrad
  when 'exakt' then 'haargenau'
  when 'richtschnur' then 'hilfetext'
  else 'angepasst'
end
where richtung = 'antworten' and verbindlichkeit is null;

alter table mailassistent_vorlage alter column verbindlichkeit set default 'angepasst';
