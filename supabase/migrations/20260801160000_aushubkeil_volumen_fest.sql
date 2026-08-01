-- ============================================================================
-- Offertentool 2027 - Pool/Wassergarten: Umfang Betonbodenplatte + Aushubkeil
-- Volumen fest.
--
-- Herleitung (bestaetigt mit Nutzer per Boeschungswinkel-Skizze):
-- Die Aushubsohle entspricht der Betonbodenplatte (Laenge x Breite), die
-- Aushubwaende boeschen von dort ueber die gesamte Aushubtiefe schraeg nach
-- aussen bis zur Gelaendeoberkante. Das dadurch zusaetzlich anfallende
-- Keilvolumen rund um den ganzen Umfang (Ecken bewusst nicht exakt
-- gerechnet, siehe Boeschungsfaktor-Ansatz des Nutzers) ergibt sich als:
--   Aushubkeil Volumen fest = 0.5 x Aushubtiefe^2 x Boeschungsfaktor x Umfang Betonbodenplatte
-- "fest" = gewachsener/eingebauter Boden vor dem Auflockern - der
-- Auflockerungsfaktor Aushub (bereits vorhanden, 1.2) kommt erst im
-- naechsten Schritt fuer "Aushubkeil Volumen lose" zum Einsatz.
--
-- Referenziert bestehende Werte ausschliesslich per Name (nicht per Id),
-- damit diese Migration unabhaengig von den tatsaechlichen UUIDs lauffaehig
-- ist. Idempotent: mehrfaches Ausfuehren legt nichts doppelt an.
-- ============================================================================

do $$
declare
  v_offertentyp_id uuid;
  v_lange_id uuid;
  v_breite_id uuid;
  v_aushubtiefe_id uuid;
  v_boeschungsfaktor_id uuid;
  v_umfang_id uuid;
  v_reihenfolge int;
begin
  select id into v_offertentyp_id from offertentyp where name = 'Pool/Wassergarten';
  if v_offertentyp_id is null then
    raise exception 'Offertentyp "Pool/Wassergarten" nicht gefunden';
  end if;

  select id into v_lange_id from term where offertentyp_id = v_offertentyp_id and name = 'Länge Betonbodenplatte';
  select id into v_breite_id from term where offertentyp_id = v_offertentyp_id and name = 'Breite Betonbodenplatte';
  select id into v_aushubtiefe_id from term where offertentyp_id = v_offertentyp_id and name = 'Aushubtiefe';
  select id into v_boeschungsfaktor_id from term where offertentyp_id = v_offertentyp_id and name = 'Böschungsfaktor Ausgub';

  if v_lange_id is null or v_breite_id is null or v_aushubtiefe_id is null or v_boeschungsfaktor_id is null then
    raise exception 'Einer der benoetigten Werte wurde nicht gefunden (Länge/Breite Betonbodenplatte, Aushubtiefe, Böschungsfaktor Ausgub) - Namen pruefen';
  end if;

  -- Umfang Betonbodenplatte = Laenge + Breite + Laenge + Breite (gleiches
  -- Muster wie das bestehende "Umfang Becken innen")
  select id into v_umfang_id from term where offertentyp_id = v_offertentyp_id and name = 'Umfang Betonbodenplatte';
  if v_umfang_id is null then
    select coalesce(max(reihenfolge), 0) + 1 into v_reihenfolge from term where offertentyp_id = v_offertentyp_id;
    insert into term (offertentyp_id, name, typ, einheit, reihenfolge, ausdruck)
    values (
      v_offertentyp_id, 'Umfang Betonbodenplatte', 'formel', 'm', v_reihenfolge,
      jsonb_build_object('op', '+', 'args', jsonb_build_array(
        jsonb_build_object('op', '+', 'args', jsonb_build_array(
          jsonb_build_object('op', '+', 'args', jsonb_build_array(
            jsonb_build_object('ref', 'term', 'id', v_lange_id),
            jsonb_build_object('ref', 'term', 'id', v_breite_id)
          )),
          jsonb_build_object('ref', 'term', 'id', v_lange_id)
        )),
        jsonb_build_object('ref', 'term', 'id', v_breite_id)
      ))
    )
    returning id into v_umfang_id;
  end if;

  -- Aushubkeil Volumen fest = 0.5 x Aushubtiefe x Aushubtiefe x Boeschungsfaktor x Umfang Betonbodenplatte
  if not exists (select 1 from term where offertentyp_id = v_offertentyp_id and name = 'Aushubkeil Volumen fest') then
    select coalesce(max(reihenfolge), 0) + 1 into v_reihenfolge from term where offertentyp_id = v_offertentyp_id;
    insert into term (offertentyp_id, name, typ, einheit, reihenfolge, ausdruck)
    values (
      v_offertentyp_id, 'Aushubkeil Volumen fest', 'formel', 'm³', v_reihenfolge,
      jsonb_build_object('op', '*', 'args', jsonb_build_array(
        jsonb_build_object('op', '*', 'args', jsonb_build_array(
          jsonb_build_object('op', '*', 'args', jsonb_build_array(
            jsonb_build_object('op', '*', 'args', jsonb_build_array(
              jsonb_build_object('lit', 0.5),
              jsonb_build_object('ref', 'term', 'id', v_aushubtiefe_id)
            )),
            jsonb_build_object('ref', 'term', 'id', v_aushubtiefe_id)
          )),
          jsonb_build_object('ref', 'term', 'id', v_boeschungsfaktor_id)
        )),
        jsonb_build_object('ref', 'term', 'id', v_umfang_id)
      ))
    );
  end if;
end $$;
