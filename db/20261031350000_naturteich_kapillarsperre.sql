-- Naturteich/Schwimmteich: der Betonstellriemen ist die Kapillarsperre rund um den TEICHRAND (Umfang Teichform), nicht um die Tiefenzone.
-- Arbeitsschritt "Betonstellriemen" wird zu "Kapillarsperre", Optionen: Betonstellriemen Lieferwagen / LKW gepumpt und neu Holzbretter (Thermokiefer).
-- Die Randschiene ist dieselbe Schiene wie die Pressschiene (gehört automatisch zur Kofra), der Artikel "Randschiene" entfällt.
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;

do $$
declare
  ot uuid; s_ut uuid; as_id uuid; ts_id uuid; af_id uuid; src uuid; opt uuid; jo jsonb; jz jsonb; a_holz uuid; k_hoehe uuid := gen_random_uuid(); k_zeit uuid := gen_random_uuid(); t_laenge uuid;
  polier uuid; garten uuid; n int;
begin
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select id into s_ut from term where offertentyp_id = ot and systemwert_key = 'form_umfang_teich';
  select id into t_laenge from term where offertentyp_id = ot and name = 'Länge Betonstellriemen';
  select id into a_holz from artikel where artikelnummer_knecht = 'DELIGN_del101';
  select id into polier from artikel where artikelnummer_knecht = 'KNECHT_000015';
  select id into garten from artikel where artikelnummer_knecht = 'KNECHT_000005';
  select s.id into as_id from arbeitsschritt s where s.offertentyp_id = ot and s.name = 'Betonstellriemen';
  if ot is null or s_ut is null or t_laenge is null or a_holz is null or as_id is null then raise exception 'Grundlagen nicht gefunden'; end if;

  -- Länge = Umfang der Teichform
  update term set name = 'Länge Kapillarsperre (Umfang Teichform)', ausdruck = pg_temp.ref_t(s_ut) where id = t_laenge;
  update term set name = 'Volumen Betonstellriemen (Kapillarsperre)' where offertentyp_id = ot and name = 'Volumen Betonstellriemen';

  -- Umbenennen
  update arbeitsschritt set name = 'Kapillarsperre' where id = as_id;
  update teilschritt set name = 'Kapillarsperre' where arbeitsschritt_id = as_id;
  update auswahlfeld set name = 'Kapillarsperre' where teilschritt_id in (select id from teilschritt where arbeitsschritt_id = as_id);
  select f.id into af_id from auswahlfeld f join teilschritt t on t.id = f.teilschritt_id where t.arbeitsschritt_id = as_id;
  update auswahloption set name = 'Kapillarsperre Betonstellriemen Lieferwagen',
    beschreibung = 'Kapillarsperre rund um den Teichrand: leichten Betonstellriemen (25 cm hoch) erstellen, Beton per Lieferwagen angeliefert.' where auswahlfeld_id = af_id and name = 'Betonstellriemen Lieferwagen';
  update auswahloption set name = 'Kapillarsperre Betonstellriemen LKW gepumpt',
    beschreibung = 'Kapillarsperre rund um den Teichrand: leichten Betonstellriemen (25 cm hoch) erstellen, Beton gepumpt.' where auswahlfeld_id = af_id and name = 'Betonstellriemen LKW gepumpt';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Option LKW gepumpt nicht gefunden'; end if;

  -- Holzbretter (Thermokiefer): Länge = Umfang Teichform, Brettfläche = Länge x Brett-Höhe, Zeit je Laufmeter
  select ao.id into src from auswahloption ao where ao.auswahlfeld_id = af_id and ao.name = 'Kapillarsperre Betonstellriemen Lieferwagen';
  select to_jsonb(o) into jo from auswahloption o where o.id = src;
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = src and rz.artikel_id = polier order by rz.reihenfolge limit 1;
  insert into term (id, offertentyp_id, name, typ, wert, einheit, reihenfolge, formel_modus) values
    (k_hoehe, ot, 'Höhe Brett Kapillarsperre (Annahme)', 'konstante', 0.25, 'm', 37, 'baukasten'),
    (k_zeit, ot, 'Zeit Holzbretter Kapillarsperre je Laufmeter (Annahme)', 'konstante', 0.3, 'Std./m', 38, 'baukasten');
  opt := gen_random_uuid();
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, jo || jsonb_build_object('id', opt, 'name', 'Kapillarsperre Holzbretter', 'reihenfolge', 3,
    'beschreibung', 'Kapillarsperre rund um den Teichrand mit Thermokiefer-Brettern erstellen.', 'hinweistext', 'Länge = Umfang Teichform, Brett 25 cm hoch.'));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1, 'kategorie', 'personal', 'artikel_id', polier,
    'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(t_laenge), pg_temp.ref_t(k_zeit)), 'notiz', 'Zuschnitt und Montage der Bretter: Annahme 0.3 Std. je Laufmeter', 'mindestmenge', null));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 2, 'kategorie', 'personal', 'artikel_id', garten,
    'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(t_laenge), pg_temp.ref_t(k_zeit)), 'notiz', 'Zuschnitt und Montage der Bretter: Annahme 0.3 Std. je Laufmeter', 'mindestmenge', null));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 3, 'kategorie', 'material', 'artikel_id', a_holz,
    'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(t_laenge), pg_temp.ref_t(k_hoehe)), 'notiz', 'Brettfläche = Länge x 0.25 m (Thermokiefer, Stellvertreter-Artikel Terrassenboden Thermo Kiefer)', 'mindestmenge', null, 'verschnitt_prozent', 10));

  -- Randschiene = Pressschiene: Artikel Randschiene entfernen, falls nirgends verwendet
  delete from artikel where artikelnummer_knecht = 'CONTEC_RANDSCHIENE'
    and not exists (select 1 from ressourcenzeile z where z.artikel_id = artikel.id);
end $$;
