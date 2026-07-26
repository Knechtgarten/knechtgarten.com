-- ============================================================================
-- Offertentool 2027 - Shop-Session (Cookie) fuers Crawling ueber Supabase
-- Vault, gleiches Muster wie das Shop-Passwort (siehe
-- 20260725340000_lieferant_shop_passwort_vault.sql).
--
-- Hintergrund: manche Shops (z.B. Koi-Breeder) pruefen beim Login ein
-- unsichtbares reCAPTCHA, das ein reiner Server-Aufruf (ohne echten Browser)
-- nicht bestehen kann. Loesung: der Admin loggt sich einmal manuell in einem
-- echten Browser ein (besteht das reCAPTCHA automatisch), kopiert danach die
-- Session ("Als cURL kopieren" in den Browser-Entwicklertools) hierher - die
-- Crawling-Funktion nutzt diese bereits eingeloggte Session direkt fuer die
-- Merklisten-Abfrage, statt selbst einzuloggen. Laeuft die Session beim Shop
-- irgendwann ab, muss der Admin sie auf die gleiche Art einmalig auffrischen.
-- ============================================================================

alter table lieferant_datenabgleich add column shop_session_secret_id uuid;

create or replace function speichere_shop_session(p_lieferant_id uuid, p_cookie text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret_id uuid;
begin
  if not ist_admin() then
    raise exception 'Nur Admins duerfen die Shop-Session speichern.';
  end if;

  select shop_session_secret_id into v_secret_id
  from lieferant_datenabgleich where lieferant_id = p_lieferant_id;

  if v_secret_id is null then
    v_secret_id := vault.create_secret(p_cookie, 'shop-session-' || p_lieferant_id::text);
    update lieferant_datenabgleich set shop_session_secret_id = v_secret_id where lieferant_id = p_lieferant_id;
  else
    perform vault.update_secret(v_secret_id, p_cookie);
  end if;
end;
$$;

create or replace function lese_shop_session(p_lieferant_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret_id uuid;
  v_cookie text;
begin
  if not ist_admin() then
    raise exception 'Nur Admins duerfen die Shop-Session lesen.';
  end if;

  select shop_session_secret_id into v_secret_id
  from lieferant_datenabgleich where lieferant_id = p_lieferant_id;

  if v_secret_id is null then
    return null;
  end if;

  select decrypted_secret into v_cookie
  from vault.decrypted_secrets where id = v_secret_id;

  return v_cookie;
end;
$$;

grant execute on function speichere_shop_session(uuid, text) to authenticated;
grant execute on function lese_shop_session(uuid) to authenticated;
