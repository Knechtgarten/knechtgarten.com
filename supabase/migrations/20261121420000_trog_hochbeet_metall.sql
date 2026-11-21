-- Bepflanzung › Tabelle «Trog, Hochbeet» für Metallgefässe (Stefan 2026-11-21)
-- Pro Zeile: Menge, Länge/Breite/Höhe (cm), Material (Cortenstahl/Alu, mit/ohne Boden), Befüllung (Landerde / Trogerde Sack / Big Bag).
-- Befüllung: bis 50 cm Höhe Landerde bzw. Trogerde, der Rest darunter Betonkies (Landerde) bzw. Blähton + Trenngewebe (Trogerde).
-- Mit/ohne Boden ist nur Konstruktion (Text), die Befüllung ist gleich.
-- Alles über versteckte Rechenspalten pro Zeile; die Mengen holen sich die Zeilen im neuen Teilschritt als Spaltensummen.
-- Der Gefässpreis (Grütter) kommt als gelbe Position pro Trog-Zeile (Konfiguration eingabefeld.zeilen_position, Code Tool A).
-- Der bisherige Teilschritt «Hochbeet / Trog befüllen» (Zuordnung über Fenster) wird ausgeblendet; keine Offerte nutzt die Tabelle mit Werten.

alter table eingabefeld add column if not exists zeilen_position jsonb;
alter table offerte_tabelle_zeile add column if not exists uid uuid;

create or replace function pg_temp.s(id uuid) returns jsonb language sql as $$ select jsonb_build_object('ref', 'spalte', 'id', id) $$;
create or replace function pg_temp.l(n numeric) returns jsonb language sql as $$ select jsonb_build_object('lit', n) $$;
create or replace function pg_temp.o(op text, variadic a jsonb[]) returns jsonb language sql as $$ select jsonb_build_object('op', op, 'args', to_jsonb(a)) $$;

do $$
declare
  ef uuid := 'c9fbb2d8-42ab-4f9a-a5b6-017c57839bb9';
  c_menge uuid := 'be969646-db84-4382-bf88-4c37c0d58f9c';
  c_hoehe uuid := '58c33ba7-313b-4891-9866-4f920a826c6f';
  c_flaeche uuid := 'eb1da15c-0d26-4f4c-9d4f-3109e61f2b8b';
  c_vol uuid := 'b8edd915-6c7c-40ab-a533-8e4e9ec8d585';
  c_laenge uuid := gen_random_uuid(); c_breite uuid := gen_random_uuid();
  c_mat uuid := gen_random_uuid(); c_bef uuid := gen_random_uuid();
  c_fh uuid := gen_random_uuid(); c_vsub uuid := gen_random_uuid(); c_vunt uuid := gen_random_uuid();
  c_land uuid := gen_random_uuid(); c_sack uuid := gen_random_uuid(); c_bb uuid := gen_random_uuid();
  c_kies uuid := gen_random_uuid(); c_blaeh uuid := gen_random_uuid(); c_gewebe uuid := gen_random_uuid(); c_std uuid := gen_random_uuid();
  a_gefaesse uuid; ts uuid;
begin
  if exists (select 1 from eingabefeld_tabelle_spalte where eingabefeld_id = ef and name = 'Material') then return; end if;

  -- Eingabespalten
  update eingabefeld_tabelle_spalte set reihenfolge = 1 where id = c_menge;
  update eingabefeld_tabelle_spalte set reihenfolge = 4 where id = c_hoehe;
  insert into eingabefeld_tabelle_spalte (id, eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausgeblendet) values
    (c_laenge, ef, 'Länge', 'cm', 2, false, false),
    (c_breite, ef, 'Breite', 'cm', 3, false, false);
  insert into eingabefeld_tabelle_spalte (id, eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausgeblendet, auswahl_werte) values
    (c_mat, ef, 'Material', '', 5, false, false, '[{"wert":1,"text":"Cortenstahl mit Boden"},{"wert":2,"text":"Cortenstahl ohne Boden"},{"wert":3,"text":"Alu mit Boden"},{"wert":4,"text":"Alu ohne Boden"}]'),
    (c_bef, ef, 'Befüllung', '', 6, false, false, '[{"wert":1,"text":"Landerde"},{"wert":2,"text":"Trogerde Sack"},{"wert":3,"text":"Trogerde Big Bag"}]');

  -- Fläche wird gerechnet (pro Stück): Länge × Breite
  update eingabefeld_tabelle_spalte set ist_berechnung = true, reihenfolge = 7, ausgeblendet = false,
    ausdruck = pg_temp.o('*', pg_temp.s(c_laenge), pg_temp.s(c_breite), pg_temp.l(0.0001))
  where id = c_flaeche;
  -- Volumen = Menge × Fläche × Höhe (bleibt sichtbar)
  update eingabefeld_tabelle_spalte set reihenfolge = 8,
    ausdruck = pg_temp.o('*', pg_temp.s(c_menge), pg_temp.s(c_flaeche), pg_temp.o('*', pg_temp.s(c_hoehe), pg_temp.l(0.01)))
  where id = c_vol;

  -- Versteckte Rechenspalten
  insert into eingabefeld_tabelle_spalte (id, eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausgeblendet, ausdruck) values
    (c_fh, ef, 'Füllhöhe Erde', 'm', 9, true, true,
      pg_temp.o('*', pg_temp.o('wenn', pg_temp.o('>', pg_temp.s(c_hoehe), pg_temp.l(50)), pg_temp.l(50), pg_temp.s(c_hoehe)), pg_temp.l(0.01))),
    (c_vsub, ef, 'Volumen Erde', 'm³', 10, true, true, pg_temp.o('*', pg_temp.s(c_menge), pg_temp.s(c_flaeche), pg_temp.s(c_fh))),
    (c_vunt, ef, 'Volumen Unterbau', 'm³', 11, true, true, pg_temp.o('-', pg_temp.s(c_vol), pg_temp.s(c_vsub))),
    (c_land, ef, 'Landerde', 'm³', 12, true, true, pg_temp.o('wenn', pg_temp.o('=', pg_temp.s(c_bef), pg_temp.l(1)), pg_temp.s(c_vsub), pg_temp.l(0))),
    (c_sack, ef, 'Trogerde Sack', 'm³', 13, true, true, pg_temp.o('wenn', pg_temp.o('=', pg_temp.s(c_bef), pg_temp.l(2)), pg_temp.s(c_vsub), pg_temp.l(0))),
    (c_bb, ef, 'Trogerde Big Bag', 'm³', 14, true, true, pg_temp.o('wenn', pg_temp.o('=', pg_temp.s(c_bef), pg_temp.l(3)), pg_temp.s(c_vsub), pg_temp.l(0))),
    (c_kies, ef, 'Betonkies', 'm³', 15, true, true, pg_temp.o('wenn', pg_temp.o('=', pg_temp.s(c_bef), pg_temp.l(1)), pg_temp.s(c_vunt), pg_temp.l(0))),
    (c_blaeh, ef, 'Blähton', 'm³', 16, true, true, pg_temp.o('wenn', pg_temp.o('>', pg_temp.s(c_bef), pg_temp.l(1)), pg_temp.s(c_vunt), pg_temp.l(0))),
    (c_gewebe, ef, 'Trenngewebe', 'm²', 17, true, true,
      pg_temp.o('wenn', pg_temp.o('>', pg_temp.s(c_blaeh), pg_temp.l(0)), pg_temp.o('*', pg_temp.s(c_menge), pg_temp.s(c_flaeche), pg_temp.l(1.2)), pg_temp.l(0))),
    (c_std, ef, 'Arbeit pro Person', 'Std.', 18, true, true,
      pg_temp.o('wenn', pg_temp.o('>', pg_temp.s(c_vol), pg_temp.l(0)),
        pg_temp.o('+', pg_temp.o('*', pg_temp.s(c_menge), pg_temp.l(0.5)),
                       pg_temp.o('*', pg_temp.s(c_vsub), pg_temp.o('wenn', pg_temp.o('=', pg_temp.s(c_bef), pg_temp.l(2)), pg_temp.l(1.33), pg_temp.l(1))),
                       pg_temp.o('*', pg_temp.s(c_vunt), pg_temp.l(0.5))),
        pg_temp.l(0)));

  -- Gelbe Position pro Trog-Zeile + Texte je Material (Code Tool A liest das)
  update eingabefeld set zeilen_position = jsonb_build_object(
    'menge', c_menge, 'laenge', c_laenge, 'breite', c_breite, 'hoehe', c_hoehe, 'material', c_mat,
    'bezeichnung', jsonb_build_object('1', 'Trog Cortenstahl mit Boden', '2', 'Trog Cortenstahl ohne Boden', '3', 'Trog Aluminium anthrazit mit Boden', '4', 'Trog Aluminium anthrazit ohne Boden'),
    'texte', jsonb_build_object(
      '1', 'Metallgefäss aus Cortenstahl mit Boden liefern und versetzen. Substrat liefern und einfüllen.',
      '2', 'Metallgefäss aus Cortenstahl ohne Boden (Rahmen, direkt auf dem gewachsenen Boden) liefern und versetzen. Substrat liefern und einfüllen.',
      '3', 'Hochwertiges Gefäss aus Aluminium mit Boden, sauber verschliffen und pulverbeschichtet in Anthrazit oder Wunschfarbe, liefern und versetzen. Substrat liefern und einfüllen.',
      '4', 'Hochwertiges Gefäss aus Aluminium ohne Boden (Rahmen, direkt auf dem gewachsenen Boden), sauber verschliffen und pulverbeschichtet in Anthrazit oder Wunschfarbe, liefern und versetzen. Substrat liefern und einfüllen.'),
    'texte_befuellung', jsonb_build_object(
      '1', 'Gefäss mit Landerde befüllen, ab 50 cm Höhe unten mit Betonkies auffüllen.',
      '2', 'Gefäss mit Trogerde befüllen, ab 50 cm Höhe unten mit Blähton und Trenngewebe.',
      '3', 'Gefäss mit Trogerde befüllen, ab 50 cm Höhe unten mit Blähton und Trenngewebe.'),
    'befuellung', c_bef)
  where id = ef;

  -- Alter Teilschritt mit Zuordnungs-Fenster aus, neuer Teilschritt mit festen Zeilen (Spaltensummen)
  select arbeitsschritt_id into a_gefaesse from teilschritt where id = 'c164ce57-2ede-45f8-b75d-152f197aa8ba';
  update teilschritt set ausgeblendet = true where id = 'c164ce57-2ede-45f8-b75d-152f197aa8ba';
  insert into teilschritt (arbeitsschritt_id, name, reihenfolge, beschreibung)
  values (a_gefaesse, 'Trog, Hochbeet', 5, null) returning id into ts;
  insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, sonderposition_typ_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
    (ts, 'personal', '006e6793-37de-46e2-8a0b-45a0065313db', null, pg_temp.o('wenn', pg_temp.o('>', pg_temp.s(c_std), pg_temp.l(0)), pg_temp.o('+', pg_temp.s(c_std), pg_temp.l(1)), pg_temp.l(0)) || '{"_einheit":"Std."}', 'baukasten', 'Versetzen + Befüllen (Tabelle Trog, Hochbeet)', 1, 1, 1, 1, 1),
    (ts, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81', null, pg_temp.o('wenn', pg_temp.o('>', pg_temp.s(c_std), pg_temp.l(0)), pg_temp.o('+', pg_temp.s(c_std), pg_temp.l(1)), pg_temp.l(0)) || '{"_einheit":"Std."}', 'baukasten', 'Versetzen + Befüllen (Tabelle Trog, Hochbeet)', 1, 1, 1, 1, 2),
    (ts, 'material', '7ae0b0d7-4eff-4dd0-b7e3-d2e46188bfb9', null, pg_temp.s(c_land) || '{"_einheit":"m³"}', 'baukasten', 'Landerde', 1, 1, 1, 1, 3),
    (ts, 'material', '2e6c4abe-26e6-40d7-a0f2-638b2ab0cd2b', null, pg_temp.s(c_kies) || '{"_einheit":"m³"}', 'baukasten', 'Betonkies unter Landerde', 1, 1, 1, 1, 4),
    (ts, 'logistik', null, '9efee272-85eb-425c-941c-d8569977e592', pg_temp.s(c_kies), 'baukasten', 'Kies-Transport Betonkies', 1, 1, 1, 1, 5),
    (ts, 'material', 'f904ab9a-dc8a-4e64-abd9-7f2ebdf66724', null, pg_temp.o('ceil', pg_temp.o('/', pg_temp.s(c_sack), pg_temp.l(0.03))) || '{"_einheit":"Sack"}', 'baukasten', 'Trogerde 30-l-Sack', 1, 1, 1, 1, 6),
    (ts, 'material', '41fbb0d5-c1cc-4244-bcc5-cc8ee1af640e', null, pg_temp.s(c_bb) || '{"_einheit":"m³"}', 'baukasten', 'Trogerde Big Bag', 1, 1, 1, 1, 7),
    (ts, 'material', '8b08b03c-7c1f-4e06-9581-0d06cf672be4', null, pg_temp.o('ceil', pg_temp.o('/', pg_temp.s(c_blaeh), pg_temp.l(0.05))) || '{"_einheit":"Sack"}', 'baukasten', 'Blähton unter Trogerde', 1, 1, 1, 1, 8),
    (ts, 'material', '3868f6af-1fcc-44b7-ae3d-791ab74f2b27', null, pg_temp.s(c_gewebe) || '{"_einheit":"m²"}', 'baukasten', 'Trenngewebe', 1, 1, 1, 1, 9);
end $$;

select s.reihenfolge, s.name, s.einheit, s.ist_berechnung, s.ausgeblendet from eingabefeld_tabelle_spalte s where s.eingabefeld_id = 'c9fbb2d8-42ab-4f9a-a5b6-017c57839bb9' order by s.reihenfolge;
