-- ============================================================================
-- Pflege-Tool: alle Zustaendigkeiten einer Person an eine andere uebertragen
-- (z.B. bei Kuendigung: Platzhalter «Patrik» -> neue Mitarbeiterin).
-- Wo die neue Person schon zustaendig ist, bleibt es bei einem Eintrag.
-- Nur Buero-Team/Admin. Gibt die Anzahl uebertragener Kunden-Kategorien zurueck.
-- ============================================================================
create or replace function pflege_zustaendig_uebertragen(von uuid, an uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not ist_buero_oder_admin() then
    raise exception 'Nur Büro-Team oder Admin dürfen Zuständigkeiten übertragen.';
  end if;
  if von = an then
    return 0;
  end if;
  select count(*) into n from pflege_kunde_kategorie_zustaendig where benutzer_id = von;
  insert into pflege_kunde_kategorie_zustaendig (kunde_kategorie_id, benutzer_id)
    select kunde_kategorie_id, an from pflege_kunde_kategorie_zustaendig where benutzer_id = von
    on conflict do nothing;
  delete from pflege_kunde_kategorie_zustaendig where benutzer_id = von;
  return n;
end;
$$;
revoke all on function pflege_zustaendig_uebertragen(uuid, uuid) from public, anon;
grant execute on function pflege_zustaendig_uebertragen(uuid, uuid) to authenticated;
