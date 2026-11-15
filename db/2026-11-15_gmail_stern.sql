-- Gmail-Stern ↔ Pendenzen (zweiseitig): Herkunft «stern», Status in pendenz_mail (stern_alt = vor dem Start markiert, stern = aktiv, stern_weg = erledigt)
alter table public.pendenz drop constraint if exists pendenz_herkunft_check;
alter table public.pendenz add constraint pendenz_herkunft_check check (herkunft = any (array['board','mail','handy','stern']));
-- Darf das Tool Gmail ändern (Stern entfernen)? Für den Knopf «Gmail-Sterne verbinden»
create or replace function public.gmail_stern_status() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'verbunden', coalesce((select scope like '%gmail.modify%' from google_verbindung where benutzer_id = auth.uid()), false),
    'aktiv', exists(select 1 from pendenz_mail where status like 'stern%'));
$$;
revoke all on function public.gmail_stern_status() from public, anon;
grant execute on function public.gmail_stern_status() to authenticated;
select 1;
