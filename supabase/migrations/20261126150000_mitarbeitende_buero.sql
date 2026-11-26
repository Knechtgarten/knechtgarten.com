-- Mitarbeitende (Kontakte) auch für Projektleiter / Büro-Team mit allen Funktionen.
-- Schutz: Nur Admins dürfen Admins ändern/löschen oder jemanden zum Admin machen.

drop policy if exists benutzer_buero_verwaltet on public.benutzer;
create policy benutzer_buero_verwaltet on public.benutzer for all
  using (public.ist_buero_oder_admin()) with check (public.ist_buero_oder_admin());

drop policy if exists benutzer_merkmal_buero on public.benutzer_merkmal;
create policy benutzer_merkmal_buero on public.benutzer_merkmal for all
  using (public.ist_buero_oder_admin()) with check (public.ist_buero_oder_admin());

drop policy if exists merkmal_buero on public.merkmal;
create policy merkmal_buero on public.merkmal for all
  using (public.ist_buero_oder_admin()) with check (public.ist_buero_oder_admin());

create or replace function public.benutzer_admin_schutz()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  alt_admin boolean := false;
  neu_admin boolean := false;
begin
  -- Service-Role (Edge Functions) und Admins: keine Einschränkung
  if auth.uid() is null or public.ist_admin() then
    return coalesce(new, old);
  end if;
  if tg_op in ('UPDATE','DELETE') then
    alt_admin := old.rolle = 'admin' or exists (select 1 from recht_gruppe g where g.id = old.recht_gruppe_id and g.ist_admin);
  end if;
  if tg_op in ('INSERT','UPDATE') then
    neu_admin := new.rolle = 'admin' or exists (select 1 from recht_gruppe g where g.id = new.recht_gruppe_id and g.ist_admin);
  end if;
  if alt_admin or neu_admin then
    raise exception 'Administratoren kann nur ein Admin ändern.';
  end if;
  return coalesce(new, old);
end $$;

drop trigger if exists benutzer_admin_schutz on public.benutzer;
create trigger benutzer_admin_schutz before insert or update or delete on public.benutzer
  for each row execute function public.benutzer_admin_schutz();
