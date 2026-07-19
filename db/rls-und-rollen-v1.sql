-- ============================================================================
-- Offertentool 2027 - Row-Level-Security + Rollenmodell (Admin / Verkauf)
-- ============================================================================
-- Admin: darf alles (Tool A, B, C - lesen und schreiben).
-- Verkauf: darf Tool A voll nutzen (Kunde/Offerte/Teilflaeche); die
--          Formel-Bibliothek/Arbeitsschritte/Artikelstamm (Tool B/C) darf
--          Verkauf nur LESEN (fuers Rechnen noetig), nicht veraendern.
-- Alles ohne gueltige Anmeldung (Rolle "anon") hat ab jetzt KEINEN Zugriff
-- mehr - vorher war die Datenbank ueber den oeffentlichen Key komplett offen.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BENUTZER-TABELLE
-- Jeder echte Login (Supabase Auth) bekommt hier eine Rolle zugewiesen.
-- Ein neuer Auth-User hat KEINE Rolle, bis ein Admin ihn hier eintraegt -
-- ohne Eintrag hier hat man also nach dem Einloggen trotzdem keinen Zugriff.
-- ----------------------------------------------------------------------------
create table benutzer (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  rolle text not null check (rolle in ('admin','verkauf')),
  erstellt_am timestamptz not null default now()
);

create or replace function ist_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid() and rolle = 'admin');
$$;

create or replace function ist_eingeloggter_benutzer()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid());
$$;

alter table benutzer enable row level security;
create policy benutzer_select_eigene_zeile on benutzer for select using (id = auth.uid() or ist_admin());
create policy benutzer_admin_verwaltet on benutzer for all using (ist_admin()) with check (ist_admin());

-- ----------------------------------------------------------------------------
-- 2. KATALOG-/DEFINITIONS-TABELLEN (Tool B/C)
-- Lesen: jeder eingeloggte, zugewiesene Benutzer (Admin ODER Verkauf).
-- Schreiben (insert/update/delete): nur Admin.
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'offertentyp','eingabefeld','term','term_abhaengigkeit','arbeitsschritt',
    'teilschritt','auswahlfeld','auswahloption','ressourcenzeile',
    'artikelgruppe','lieferant','artikel'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_lesen on %I for select using (ist_eingeloggter_benutzer());', t, t);
    execute format('create policy %I_admin_schreibt on %I for all using (ist_admin()) with check (ist_admin());', t, t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 3. OFFERTEN-DATEN (Tool A)
-- Voller Zugriff (lesen/schreiben) fuer jeden eingeloggten, zugewiesenen
-- Benutzer - Admin und Verkauf gleichermassen.
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'kunde','offerte','teilflaeche','teilflaeche_eingabefeld_wert','teilflaeche_auswahl'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_voller_zugriff on %I for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());', t, t);
  end loop;
end $$;

-- ============================================================================
-- NAECHSTER SCHRITT (manuell, nicht per SQL):
-- 1. Im Supabase-Dashboard unter Authentication > Users den ersten echten
--    Benutzer anlegen (deine eigene Mailadresse + Passwort).
-- 2. Dessen User-ID kopieren und damit den ersten Admin-Eintrag anlegen:
--      insert into benutzer (id, email, rolle)
--      values ('<user-id-einfuegen>', '<deine-mailadresse>', 'admin');
-- Ohne diesen Eintrag kann sich zwar jeder registrierte Auth-User einloggen,
-- bekommt aber (dank ist_eingeloggter_benutzer()) trotzdem nirgends Zugriff.
-- ============================================================================
