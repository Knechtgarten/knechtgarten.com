-- ============================================================================
-- Mail-Assistent: Fremdschluessel auf ON DELETE SET NULL umgestellt - beim
-- Loeschen einer Kategorie/Unterkategorie verlieren zugeordnete Vorlagen nur
-- ihre Zuordnung (wandern zu "Noch nicht zugeordnet"), statt dass das
-- Loeschen mit einem Fremdschluessel-Fehler fehlschlaegt.
-- ============================================================================

alter table mailassistent_vorlage drop constraint if exists mailassistent_vorlage_kategorie_id_fkey;
alter table mailassistent_vorlage add constraint mailassistent_vorlage_kategorie_id_fkey
  foreign key (kategorie_id) references mailassistent_kategorie(id) on delete set null;

alter table mailassistent_vorlage drop constraint if exists mailassistent_vorlage_unterkategorie_id_fkey;
alter table mailassistent_vorlage add constraint mailassistent_vorlage_unterkategorie_id_fkey
  foreign key (unterkategorie_id) references mailassistent_unterkategorie(id) on delete set null;

alter table mailassistent_unterkategorie drop constraint if exists mailassistent_unterkategorie_kategorie_id_fkey;
alter table mailassistent_unterkategorie add constraint mailassistent_unterkategorie_kategorie_id_fkey
  foreign key (kategorie_id) references mailassistent_kategorie(id) on delete cascade;
