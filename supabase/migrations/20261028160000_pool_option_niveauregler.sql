-- Pool/Wassergarten, Teilschritt "Wasseraufbereitung automatisch mit Filtersteuerung": neue Option "Niveauregler"
-- (Nutzerwunsch 2026-10-28): Wasserstandsregler Skimmer Level Control (AQUASOL_081131) + Magnetventil fuer Wasserstandsregelung
-- (AQUASOL_081083) + 3 Std. Pooltechniker (Polier / Vorarbeiter Wassergaerten Spezialpreis, wie bei den anderen Optionen).
-- Aufbau wie die Zusatz-Optionen "+ Space Fr. Chlor" (eigene Offertenposition, mit anderen Optionen kombinierbar).
do $$
declare
  af constant uuid := '4c4282a2-3aa8-4f92-b978-48bee555f365';
  src uuid; opt uuid := gen_random_uuid(); j jsonb; rr int;
  a_regler uuid; a_ventil uuid; a_pool constant uuid := '8fa14723-4de8-4395-a50a-4f72c11e9a7a';
  rz_mat jsonb; rz_per jsonb;
begin
  if exists (select 1 from auswahloption where auswahlfeld_id = af and name = 'Niveauregler') then raise exception 'Niveauregler existiert schon'; end if;
  select id into a_regler from artikel where artikelnummer_knecht = 'AQUASOL_081131';
  select id into a_ventil from artikel where artikelnummer_knecht = 'AQUASOL_081083';
  if a_regler is null or a_ventil is null then raise exception 'Artikel nicht gefunden'; end if;
  select id into src from auswahloption where auswahlfeld_id = af and name = '+ Space Fr. Chlor';
  if src is null then raise exception 'Quelloption fehlt'; end if;
  select coalesce(max(reihenfolge), 0) + 1 into rr from auswahloption where auswahlfeld_id = af;

  select to_jsonb(o) into j from auswahloption o where o.id = src;
  j := j || jsonb_build_object('id', opt, 'name', 'Niveauregler', 'reihenfolge', rr,
        'beschreibung', 'Niveauregler (automatische Wasserstandsregelung) liefern und montieren.');
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j);

  select to_jsonb(rz) into rz_mat from ressourcenzeile rz where rz.option_id = src and rz.kategorie = 'material' limit 1;
  select to_jsonb(rz) into rz_per from ressourcenzeile rz where rz.option_id = src and rz.kategorie = 'personal' limit 1;
  if rz_mat is null or rz_per is null then raise exception 'Quellzeilen fehlen'; end if;

  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, rz_mat || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1, 'artikel_id', a_regler, 'menge_ausdruck', jsonb_build_object('lit', 1, '_einheit', 'Stk.')));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, rz_mat || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 2, 'artikel_id', a_ventil, 'menge_ausdruck', jsonb_build_object('lit', 1, '_einheit', 'Stk.')));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, rz_per || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 3, 'artikel_id', a_pool, 'menge_ausdruck', jsonb_build_object('lit', 3, '_einheit', 'Std.')));
end $$;
