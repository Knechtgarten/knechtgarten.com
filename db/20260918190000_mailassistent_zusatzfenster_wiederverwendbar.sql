-- ============================================================================
-- Mail-Assistent: Zusatzfenster von "1 Vorlage = 1 Zusatzfenster" loesen.
--
-- Bisher haengte ein Zusatzfenster fix an genau einer Vorlage (vorlage_id,
-- unique). Neu sind Zusatzfenster eine eigene, wiederverwendbare Bibliothek:
-- ein Zusatzfenster kann mehreren Vorlagen zugewiesen werden, und eine
-- Vorlage kann mehrere Zusatzfenster haben (z.B. zwei verschiedene Tabellen
-- in derselben Mail). Die Zuordnung ist bewusst eine EIGENE Tabelle (nicht
-- nur ueber den Platzhalter-Text im Vorlagen-Inhalt erkannt) - sonst wuesste
-- die Erweiterung beim Anklicken einer Vorlage nicht zuverlaessig, welche
-- Zusatzfenster-Tabellen aufploppen sollen.
--
-- Der Platzhalter wird ab jetzt beim Erstellen automatisch generiert (Titel-
-- Slug + Kurz-ID) und bleibt danach stabil, auch wenn der Titel spaeter
-- geaendert wird - sonst wuerden bereits eingefuegte Platzhalter in
-- Vorlagen-Texten ploetzlich ins Leere laufen.
-- ============================================================================

create table mailassistent_vorlage_zusatzfenster (
  vorlage_id uuid not null references mailassistent_vorlage(id) on delete cascade,
  zusatzfenster_id uuid not null references mailassistent_zusatzfenster(id) on delete cascade,
  primary key (vorlage_id, zusatzfenster_id)
);
alter table mailassistent_vorlage_zusatzfenster enable row level security;
create policy mailassistent_vorlage_zusatzfenster_buero_admin
  on mailassistent_vorlage_zusatzfenster for all
  using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- Bestehende 1:1-Verknuepfungen in die neue Zuordnungstabelle uebernehmen,
-- bevor die alte Spalte entfernt wird.
insert into mailassistent_vorlage_zusatzfenster (vorlage_id, zusatzfenster_id)
select vorlage_id, id from mailassistent_zusatzfenster where vorlage_id is not null;

-- Platzhalter eindeutig machen (Titel-Slug + Kurz-ID aus der eigenen id),
-- damit die neue Unique-Regel unten nicht an vorhandenen Duplikaten
-- (mehrere Test-Eintraege mit dem alten Default "[BESTELLLISTE]") scheitert.
update mailassistent_zusatzfenster
set platzhalter = '[ZF:' || regexp_replace(lower(coalesce(nullif(trim(titel), ''), 'tabelle')), '[^a-z0-9]+', '-', 'g') || '-' || substr(id::text, 1, 6) || ']';

alter table mailassistent_zusatzfenster
  add constraint mailassistent_zusatzfenster_platzhalter_key unique (platzhalter);

alter table mailassistent_zusatzfenster drop column if exists vorlage_id;
