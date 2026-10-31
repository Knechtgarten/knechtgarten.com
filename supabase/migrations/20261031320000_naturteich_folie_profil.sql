-- Naturteich/Schwimmteich: Folien- und Vliesfläche nach dem Profil statt Böschungsfaktor.
--  Folie netto = Boden Tiefenzone + Wand Tiefenzone (Umfang x Mauerhöhe) + schräge Randzone + 30 cm über den Rand ringsum
--  schräge Randzone = mittlerer Umfang x Länge der Schräge, Schräge = Wurzel(Breite Randzone² + Wassertiefe²), ohne Wurzelfunktion genähert
--                     (ein Newton-Schritt mit Startwert 0.75 x (Breite + Tiefe), Fehler unter 1 %), Breite Randzone = Fläche Randzone / mittlerer Umfang
--  Folie  = netto x Zuschlag Ecken und Falten x (1 + Überlappung 8 cm / Bahnbreite Folie)
--  Vlies  = 2 x netto (unter und über der Folie) x Zuschlag Ecken und Falten x (1 + Überlappung / Bahnbreite Vlies)
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;
create or replace function pg_temp.ref_e(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'eingabefeld') $$;
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.add(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '+', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.dv(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '/', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.lit(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;

do $$
declare
  ot uuid; s_ut uuid; s_ff uuid; s_uf uuid; s_fr uuid; e_wt uuid; e_mh uuid; f_folie uuid; k_zusatz uuid; k_boesch uuid;
  k_rand uuid := gen_random_uuid(); k_ueberl uuid := gen_random_uuid(); k_bahnf uuid := gen_random_uuid(); k_bahnv uuid := gen_random_uuid();
  t_umittel uuid := gen_random_uuid(); t_wrand uuid := gen_random_uuid(); t_g uuid := gen_random_uuid(); t_s uuid := gen_random_uuid(); t_netto uuid := gen_random_uuid(); t_vlies uuid := gen_random_uuid();
  opt uuid; n int;
begin
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select id into s_ut from term where offertentyp_id = ot and systemwert_key = 'form_umfang_teich';
  select id into s_ff from term where offertentyp_id = ot and systemwert_key = 'form_flaeche_tief';
  select id into s_uf from term where offertentyp_id = ot and systemwert_key = 'form_umfang_tief';
  select id into s_fr from term where offertentyp_id = ot and systemwert_key = 'form_flaeche_rand';
  select id into e_wt from eingabefeld where offertentyp_id = ot and name = 'Wassertiefe';
  select id into e_mh from eingabefeld where offertentyp_id = ot and name = 'Mauerhöhe';
  select id into f_folie from term where offertentyp_id = ot and name = 'Folienfläche inkl. Zuschlag';
  select id into k_zusatz from term where offertentyp_id = ot and name = 'Folienzuschlag (Faktor)';
  select id into k_boesch from term where offertentyp_id = ot and name = 'Böschungsfaktor Folie';
  if ot is null or s_ut is null or s_ff is null or s_uf is null or s_fr is null or e_wt is null or e_mh is null or f_folie is null or k_zusatz is null or k_boesch is null then raise exception 'Grundlagen nicht gefunden'; end if;

  -- Konstanten
  update term set name = 'Zuschlag Ecken und Falten', wert = 1.05 where id = k_zusatz;
  insert into term (id, offertentyp_id, name, typ, wert, einheit, reihenfolge, formel_modus) values
    (k_rand, ot, 'Folie über den Rand hinaus', 'konstante', 0.3, 'm', 24, 'baukasten'),
    (k_ueberl, ot, 'Überlappung Bahnen', 'konstante', 0.08, 'm', 25, 'baukasten'),
    (k_bahnf, ot, 'Bahnbreite Folie (Annahme)', 'konstante', 5, 'm', 26, 'baukasten'),
    (k_bahnv, ot, 'Bahnbreite Vlies', 'konstante', 2.65, 'm', 27, 'baukasten');

  -- Hilfswerte der Randzone
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (t_umittel, ot, 'Mittlerer Umfang Randzone', 'formel', pg_temp.mul(pg_temp.add(pg_temp.ref_t(s_ut), pg_temp.ref_t(s_uf)), pg_temp.lit(0.5)), 'm', 28, 'baukasten'),
    (t_wrand, ot, 'Mittlere Breite Randzone', 'formel', pg_temp.dv(pg_temp.ref_t(s_fr), pg_temp.add(pg_temp.ref_t(t_umittel), pg_temp.lit(0.000001))), 'm', 29, 'baukasten'),
    (t_g, ot, 'Hilfswert Schräge Randzone', 'formel', pg_temp.mul(pg_temp.add(pg_temp.ref_t(t_wrand), pg_temp.ref_e(e_wt)), pg_temp.lit(0.75)), 'm', 30, 'baukasten');
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (t_s, ot, 'Länge Schräge Randzone', 'formel',
      pg_temp.mul(pg_temp.add(pg_temp.ref_t(t_g), pg_temp.dv(pg_temp.add(pg_temp.mul(pg_temp.ref_t(t_wrand), pg_temp.ref_t(t_wrand)), pg_temp.mul(pg_temp.ref_e(e_wt), pg_temp.ref_e(e_wt))), pg_temp.add(pg_temp.ref_t(t_g), pg_temp.lit(0.000001)))), pg_temp.lit(0.5)), 'm', 31, 'baukasten');
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (t_netto, ot, 'Folienfläche netto (Profil und Rand)', 'formel',
      pg_temp.add(pg_temp.add(pg_temp.add(pg_temp.ref_t(s_ff), pg_temp.mul(pg_temp.ref_t(s_uf), pg_temp.ref_e(e_mh))), pg_temp.mul(pg_temp.ref_t(t_umittel), pg_temp.ref_t(t_s))), pg_temp.mul(pg_temp.ref_t(s_ut), pg_temp.ref_t(k_rand))), 'm²', 32, 'baukasten');
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (t_vlies, ot, 'Vliesfläche (unter und über der Folie)', 'formel',
      pg_temp.mul(pg_temp.mul(pg_temp.mul(pg_temp.lit(2), pg_temp.ref_t(t_netto)), pg_temp.ref_t(k_zusatz)), pg_temp.add(pg_temp.lit(1), pg_temp.dv(pg_temp.ref_t(k_ueberl), pg_temp.ref_t(k_bahnv)))), 'm²', 33, 'baukasten');

  -- Folienfläche (bestehender Wert, wird auch von den Zeilen verwendet) auf die neue Rechnung umstellen
  update term set name = 'Folienfläche inkl. Überlappung und Zuschlag',
    ausdruck = pg_temp.mul(pg_temp.mul(pg_temp.ref_t(t_netto), pg_temp.ref_t(k_zusatz)), pg_temp.add(pg_temp.lit(1), pg_temp.dv(pg_temp.ref_t(k_ueberl), pg_temp.ref_t(k_bahnf)))) where id = f_folie;

  -- Vlies-Zeile rechnet jetzt mit der Vliesfläche
  select ao.id into opt from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = ot and s.name = 'Folie und Vlies' and ao.name = 'Teichfolie verlegen';
  update ressourcenzeile set menge_ausdruck = pg_temp.ref_t(t_vlies), notiz = 'Menge = Vliesfläche (unter und über der Folie)'
   where option_id = opt and artikel_id = (select id from artikel where artikelnummer_knecht = 'KNECHT_TEICH_VLIES_800');
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Vlies-Zeile nicht gefunden'; end if;
  update auswahloption set hinweistext = 'Folie: Boden, Wand und Schräge plus 30 cm über den Rand, mit Überlappung 8 cm und Zuschlag für Ecken. Vlies doppelt (unter und über der Folie).' where id = opt;

  -- Der Böschungsfaktor wird nicht mehr gebraucht (nur wenn nirgends mehr verwendet)
  if not exists (select 1 from term where offertentyp_id = ot and ausdruck::text like '%' || k_boesch::text || '%')
     and not exists (select 1 from ressourcenzeile where menge_ausdruck::text like '%' || k_boesch::text || '%') then
    delete from term where id = k_boesch;
  end if;
end $$;
