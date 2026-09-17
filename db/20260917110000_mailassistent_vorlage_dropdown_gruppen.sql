-- ============================================================================
-- Mail-Assistent: Dropdown-Gruppen fuer Verfassen-Vorlagen.
--
-- Bei vielen aehnlichen Vorlagen (z.B. mehrere Bestellungs-Vorlagen) wird die
-- Chip-Leiste in der Erweiterung unuebersichtlich. Neu koennen mehrere
-- Vorlagen unter einem gemeinsamen Dropdown-Button gebuendelt werden.
--
-- Datenmodell: eine Dropdown-Gruppe ist selbst eine Zeile in
-- mailassistent_vorlage (typ='dropdown', nur der Titel als Beschriftung fuer
-- den Button, kein Inhalt) - normale Vorlagen bekommen ueber parent_id einen
-- Verweis auf ihre Gruppe. Eine Vorlage ohne parent_id bleibt wie bisher auf
-- der obersten Ebene sichtbar. Gruppen selbst haben immer parent_id = null
-- (keine verschachtelten Dropdowns noetig).
-- ============================================================================

alter table mailassistent_vorlage
  add column if not exists parent_id uuid references mailassistent_vorlage(id) on delete cascade;

create index if not exists idx_mailassistent_vorlage_parent on mailassistent_vorlage(parent_id);

-- Alten Check-Constraint auf "typ" per Systemkatalog finden statt den Namen
-- zu vermuten (Postgres vergibt bei unbenannten Constraints zwar meist das
-- Muster <tabelle>_<spalte>_check, das ist aber nicht garantiert).
do $$
declare
  con record;
begin
  for con in
    select conname from pg_constraint
    where conrelid = 'mailassistent_vorlage'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%typ%einfach%rueckfrage%'
  loop
    execute format('alter table mailassistent_vorlage drop constraint %I', con.conname);
  end loop;
end $$;

alter table mailassistent_vorlage add constraint mailassistent_vorlage_typ_check
  check (typ in ('einfach','rueckfrage','dropdown'));
