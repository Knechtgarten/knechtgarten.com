-- Projektleitung als erster Arbeitsschritt (Stefan 2026-11-21)
-- Knöpfe = Stunden «Projektleiter» (KNECHT_000030), Einfachauswahl, nichts vorgewählt (= ohne Projektleitung).
-- Der Hinweis beim Darüberfahren sagt, wann welcher Knopf passt. Rasen, Zeit, Easy, KI und alte Vorlagen: keine Projektleitung.
do $$
declare
  pl uuid := '89b21536-9c59-40fb-88ab-9bb1c16e2beb';
  v record; ot uuid; a uuid; t uuid; f uuid; o uuid; i int;
begin
  for v in select * from (values
    ('Pool/Wassergarten', jsonb_build_array(
      jsonb_build_array(2,  'Badebrunnen einfach'),
      jsonb_build_array(4,  'Pool einfach oder Badebrunnen umfassend (komplex, weit entfernt)'),
      jsonb_build_array(8,  'Pool umfassend (viel Technik, viele Gewerke)'),
      jsonb_build_array(12, 'Pool extern einfach: nur Pool durch uns, Umgebung durch Dritte'),
      jsonb_build_array(16, 'Pool extern umfassend: nur Pool durch uns, Umgebung durch Dritte, viel Technik'))),
    ('Naturteich/Schwimmteich', jsonb_build_array(
      jsonb_build_array(2,  'Biotop oder Wasseranlage einfach'),
      jsonb_build_array(4,  'Schwimmteich einfach oder Wasseranlage umfassend'),
      jsonb_build_array(8,  'Schwimmteich umfassend'),
      jsonb_build_array(12, 'Schwimmteich extern einfach: Umgebung durch Dritte'),
      jsonb_build_array(16, 'Schwimmteich extern umfassend: Umgebung durch Dritte, viel Technik'))),
    ('Pooloptionen', jsonb_build_array(
      jsonb_build_array(2,  'Eine Anlage für sich: z. B. Wärmepumpe, Elektroheizung, Gegenstromanlage oder Wärmetauscher (nur Dusche oder Roboter: keinen Knopf wählen)'),
      jsonb_build_array(4,  'Wärmetauscher oder Gegenstromanlage zusammen mit weiteren Anlagen (z. B. Wärmepumpe)'))),
    ('Bepflanzung', jsonb_build_array(
      jsonb_build_array(2,  'Grössere Pflanzenbestellung ohne Beratung'),
      jsonb_build_array(4,  'Pflanzberatung vor Ort'),
      jsonb_build_array(8,  'Pflanzberatung und Pflanzkonzept umfassend'))),
    ('Beläge, Hartflächen', jsonb_build_array(
      jsonb_build_array(2,  'Umfassende Belagsarbeiten'))),
    ('Holzdeck', jsonb_build_array(
      jsonb_build_array(2,  'Holzdeck einfach'),
      jsonb_build_array(4,  'Holzdeck umfassend'))),
    ('Mauern', jsonb_build_array(
      jsonb_build_array(2,  'Mauer einfach'),
      jsonb_build_array(4,  'Mauern umfassend'))),
    ('Regenwassertank', jsonb_build_array(
      jsonb_build_array(4,  'Regenwassertank'))),
    ('Bewässerung', jsonb_build_array(
      jsonb_build_array(2,  'Bewässerung einfach'),
      jsonb_build_array(4,  'Bewässerung umfassend'))),
    ('Gartenbeleuchtung', jsonb_build_array(
      jsonb_build_array(2,  'Beleuchtung einfach'),
      jsonb_build_array(4,  'Beleuchtung umfassend')))
  ) x(typ, knoepfe) loop
    select id into ot from offertentyp where name = v.typ;
    if ot is null or exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Projektleitung') then continue; end if;
    insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
    values (ot, 'Projektleitung', coalesce((select min(reihenfolge) from arbeitsschritt where offertentyp_id = ot), 1) - 1) returning id into a;
    insert into teilschritt (arbeitsschritt_id, name, reihenfolge) values (a, 'Projektleitung', 1) returning id into t;
    insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (t, 'Projektleitung', 1) returning id into f;
    for i in 0 .. jsonb_array_length(v.knoepfe) - 1 loop
      insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
      values (f, (v.knoepfe->i->>0) || ' Std.', i + 1, null, v.knoepfe->i->>1, false, false, 'Std.', false, false) returning id into o;
      insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
      values (o, 'personal', pl, jsonb_build_object('lit', (v.knoepfe->i->>0)::numeric, '_einheit', 'Std.'), 'baukasten', 'Projektleitung', 1, 1, 1, 1, 1);
    end loop;
  end loop;
end $$;

select ot.name, string_agg(o.name, ' · ' order by o.reihenfolge) knoepfe
from arbeitsschritt a join offertentyp ot on ot.id = a.offertentyp_id join teilschritt t on t.arbeitsschritt_id = a.id join auswahlfeld f on f.teilschritt_id = t.id join auswahloption o on o.auswahlfeld_id = f.id
where a.name = 'Projektleitung' group by ot.name order by ot.name;
