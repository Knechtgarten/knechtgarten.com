-- ============================================================================
-- Offertentool 2027 - Shop-Login-Passwort fuers Crawling ueber Supabase Vault
-- echt verschluesseln (nicht wie API-Key/FTP-Passwort unverschluesselt in
-- sync_verbindung). Es wird nur die Vault-Secret-Id gespeichert, nie der
-- Klartext direkt in lieferant_datenabgleich/sync_verbindung.
-- ============================================================================

alter table lieferant_datenabgleich add column shop_passwort_secret_id uuid;

create or replace function speichere_shop_passwort(p_lieferant_id uuid, p_passwort text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret_id uuid;
begin
  if not ist_admin() then
    raise exception 'Nur Admins duerfen das Shop-Passwort speichern.';
  end if;

  select shop_passwort_secret_id into v_secret_id
  from lieferant_datenabgleich where lieferant_id = p_lieferant_id;

  if v_secret_id is null then
    v_secret_id := vault.create_secret(p_passwort, 'shop-passwort-' || p_lieferant_id::text);
    update lieferant_datenabgleich set shop_passwort_secret_id = v_secret_id where lieferant_id = p_lieferant_id;
  else
    perform vault.update_secret(v_secret_id, p_passwort);
  end if;
end;
$$;

create or replace function lese_shop_passwort(p_lieferant_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret_id uuid;
  v_passwort text;
begin
  if not ist_admin() then
    raise exception 'Nur Admins duerfen das Shop-Passwort lesen.';
  end if;

  select shop_passwort_secret_id into v_secret_id
  from lieferant_datenabgleich where lieferant_id = p_lieferant_id;

  if v_secret_id is null then
    return null;
  end if;

  select decrypted_secret into v_passwort
  from vault.decrypted_secrets where id = v_secret_id;

  return v_passwort;
end;
$$;

grant execute on function speichere_shop_passwort(uuid, text) to authenticated;
grant execute on function lese_shop_passwort(uuid) to authenticated;
