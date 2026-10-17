-- Benutzer: Anzeigename + Haekchen «im Pflege-Tool zustaendig».
-- Nur angehakte Benutzer erscheinen im Pflege-Tool bei «Zustaendig» (sonst
-- tauchten Sammel-Logins wie bau@/info@ auf). Gepflegt unter Verwaltung › Benutzer.
alter table benutzer add column if not exists anzeigename text null;
alter table benutzer add column if not exists pflege_zustaendig boolean not null default false;

-- Rueckgabe erweitert -> Funktion neu anlegen. Liefert alle aktiven Benutzer
-- mit Flag; das Pflege-Tool bietet nur angehakte zur Auswahl an, zeigt aber
-- bereits zugeordnete weiterhin mit Namen an.
drop function if exists pflege_zustaendige();
create function pflege_zustaendige()
returns table (id uuid, email text, rolle text, anzeigename text, pflege_zustaendig boolean)
language sql
security definer
stable
set search_path = public
as $$
  select b.id, b.email, b.rolle, b.anzeigename, b.pflege_zustaendig
  from benutzer b
  where ist_eingeloggter_benutzer() and b.aktiv and b.rolle is not null
  order by coalesce(b.anzeigename, b.email);
$$;
revoke all on function pflege_zustaendige() from public, anon;
grant execute on function pflege_zustaendige() to authenticated;
