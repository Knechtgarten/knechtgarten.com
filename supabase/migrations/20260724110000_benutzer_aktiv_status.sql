-- ============================================================================
-- Offertentool 2027 - Benutzer aktivieren/deaktivieren.
--
-- Bisher gab es nur "keine Rolle" (= gesperrt) oder "Rolle zugewiesen" (=
-- voller Zugriff) - kein Weg, einen ausgeschiedenen Mitarbeiter zu sperren,
-- ohne seinen benutzer-Eintrag komplett zu loeschen. Neu: ein aktiv-Flag,
-- das unabhaengig von der Rolle den Zugriff sperren kann (z.B. bei
-- Austritt), ohne den Eintrag/die Rollen-Zuweisung selbst zu verlieren.
-- ============================================================================

alter table benutzer add column aktiv boolean not null default true;

create or replace function ist_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid() and rolle = 'admin' and aktiv);
$$;

create or replace function ist_eingeloggter_benutzer()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid() and rolle is not null and aktiv);
$$;
