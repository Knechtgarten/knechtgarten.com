-- ============================================================================
-- Offertentool 2027 - Systemwert-Keys umbenannt: "Hin+Rueck" -> "einfache Fahrt"
-- (Nachtrag zu systemwert-terms-v1.sql, das schon ausgefuehrt wurde).
--
-- Der Systemwert liefert bewusst nur die einfache Fahrt - fuer Hin+Rueck wird
-- in der Menge-Formel selbst mit *2 multipliziert.
-- ============================================================================

-- Falls schon ein Term mit den alten Keys angelegt wurde, umbenennen statt
-- kaputt zu lassen (harmlos, falls keine Zeilen betroffen sind).
update term set systemwert_key = 'fahrzeit_einfach_std' where systemwert_key = 'fahrzeit_hin_rueck_std';
update term set systemwert_key = 'distanz_einfach_km' where systemwert_key = 'distanz_hin_rueck_km';

-- Alte Check-Constraints dynamisch entfernen (Namen koennen variieren) und mit
-- den neuen, umbenannten Keys neu anlegen - gleiches Muster wie im
-- urspruenglichen Migrationsskript.
do $$
declare
  c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'term'::regclass and contype = 'c'
  loop
    execute format('alter table term drop constraint %I;', c.conname);
  end loop;
end $$;

alter table term add constraint term_typ_check check (typ in ('formel', 'konstante', 'systemwert'));
alter table term add constraint term_felder_check check (
  (typ = 'konstante' and wert is not null and ausdruck is null and systemwert_key is null) or
  (typ = 'formel' and ausdruck is not null and wert is null and systemwert_key is null) or
  (typ = 'systemwert' and systemwert_key is not null and wert is null and ausdruck is null)
);
alter table term add constraint term_systemwert_key_check check (systemwert_key in ('fahrzeit_einfach_std', 'distanz_einfach_km'));
