-- Regenwassertank: HGC-Angebot 21033514 vom 03.11.2026 (PLATIN Flachtank Pakete).
-- EK = Preis nach 22 % Rabatt (ohne MwSt), VK = Listenpreis (UVP). Transport ab HGC 200.- bis / 230.- ab 7500 L, ohne Abladen.
-- Bestehende Tankgruppen (1500-15000 L) heissen neu «Garten-Komfort» und bekommen Tank-Artikel + Transport.
-- Neuer Teilschritt «Haus Professionell» (3000-15000 L) als Kopie davon mit den Professional-Artikeln.
do $$
declare
  ot uuid; as_id uuid; ts_k uuid; af_k uuid; ts_p uuid := gen_random_uuid(); af_p uuid := gen_random_uuid();
  t_old jsonb; lief uuid; a_t_bis uuid := gen_random_uuid(); a_t_ab uuid := gen_random_uuid();
  old1 uuid; old2 uuid;
  k record; r record; z record; tpl jsonb; tpl_log jsonb; groesse int; new_o uuid; gmap jsonb := '{}'::jsonb; g text;
  komfort jsonb := '{}'::jsonb; prof jsonb := '{}'::jsonb; a_id uuid; a_tr uuid;
begin
  select id into ot from offertentyp where name='Regenwassertank' and papierkorb_am is null;
  select a.id into as_id from arbeitsschritt a where a.offertentyp_id=ot and a.name='Regenwassertank liefern und montieren';
  select t.id into ts_k from teilschritt t where t.arbeitsschritt_id=as_id and t.name='Regenwassertank';
  select f.id into af_k from auswahlfeld f where f.teilschritt_id=ts_k;
  select to_jsonb(a), a.lieferant_id into t_old, lief from artikel a where a.artikelnummer_knecht='HGC_900000503';
  select id into old1 from artikel where artikelnummer_knecht='HGC_900000503';
  select id into old2 from artikel where artikelnummer_knecht='HGC_900000502';
  if ot is null or as_id is null or ts_k is null or af_k is null or t_old is null then raise exception 'Grundlagen fehlen'; end if;

  -- Tank-Artikel: Linie, Liter, Lieferanten-Nr, Bezeichnung, EK netto, VK (UVP)
  for k in select * from (values
    ('K',1500,'100135138','PLATIN Flachtank Paket 1500 L Garten-Komfort, begehbar CH',2047.49,2624.99),
    ('K',3000,'100135139','PLATIN Flachtank Paket 3000 L Garten-Komfort, begehbar CH',2700.58,3462.28),
    ('K',5000,'100135140','PLATIN Flachtank Paket 5000 L Garten-Komfort, begehbar CH',3334.76,4275.33),
    ('K',7500,'100135161','PLATIN Flachtank Paket 7500 L Garten-Komfort, begehbar CH',4093.41,5247.96),
    ('K',10000,'100135162','PLATIN XL Flachtank Paket 10000 L DN160 Garten-Komfort, begehbar CH',5695.01,7301.29),
    ('K',15000,'100135163','PLATIN XL Flachtank Paket 15000 L DN160 Garten-Komfort, begehbar CH',7636.15,9789.93),
    ('P',3000,'900000503','PLATIN Flachtank Paket 3000 L Haus Professionell, begehbar',4870.32,6244.00),
    ('P',5000,'900000503','PLATIN Flachtank Paket 5000 L Haus Professionell, begehbar',5295.42,6789.00),
    ('P',7500,'900000503','PLATIN Flachtank Paket 7500 L Haus Professionell, begehbar',6041.10,7745.00),
    ('P',10000,'900000503','PLATIN XL Flachtank Paket 10000 L DN160 Haus Professionell, begehbar',7523.10,9645.00),
    ('P',15000,'900000503','PLATIN XL Flachtank Paket 15000 L DN160 Haus Professionell, begehbar',9488.70,12165.00)
  ) v(linie, liter, nr, bez, ek, vk) loop
    a_id := gen_random_uuid();
    insert into artikel select (jsonb_populate_record(null::artikel, t_old || jsonb_build_object('id', a_id,
      'artikelnummer_knecht', case when k.linie='K' then 'HGC_'||k.nr else 'HGC_PROF_'||k.liter end,
      'artikelnummer_lieferant', case when k.linie='K' then k.nr else k.nr||'-'||k.liter end, 'bezeichnung', k.bez, 'ep_lieferant', k.ek, 'vp_knecht', k.vk, 'erstellt_am', now(),
      'anmerkung', 'HGC-Angebot 21033514 vom 03.11.2026: Listenpreis '||k.vk||', Rabatt 22 %. Transport separat.', 'easybill_id', null))).*;
    if k.linie='K' then komfort := komfort || jsonb_build_object(k.liter::text, a_id); else prof := prof || jsonb_build_object(k.liter::text, a_id); end if;
  end loop;

  -- Transport ab HGC (ohne Abladen)
  insert into artikel select (jsonb_populate_record(null::artikel, t_old || jsonb_build_object('id', a_t_bis, 'artikelnummer_knecht', 'HGC_TRANSPORT_TANK_BIS7500', 'artikelnummer_lieferant', null,
    'bezeichnung', 'Transport Flachtank ab HGC bis 7500 L (ohne Abladen)', 'kategorie', 'logistik', 'ep_lieferant', 200, 'vp_knecht', 250, 'foto_url', null, 'erstellt_am', now(),
    'anmerkung', 'HGC-Angebot 21033514: Transportkosten bis 7500 L = 200.-, ohne Abladen', 'easybill_id', null))).*;
  insert into artikel select (jsonb_populate_record(null::artikel, t_old || jsonb_build_object('id', a_t_ab, 'artikelnummer_knecht', 'HGC_TRANSPORT_TANK_AB7500', 'artikelnummer_lieferant', null,
    'bezeichnung', 'Transport Flachtank ab HGC ab 7500 L (ohne Abladen)', 'kategorie', 'logistik', 'ep_lieferant', 230, 'vp_knecht', 287.5, 'foto_url', null, 'erstellt_am', now(),
    'anmerkung', 'HGC-Angebot 21033514: Transportkosten ab 7500 L = 230.-, ohne Abladen', 'easybill_id', null))).*;

  -- Garten-Komfort: Tank-Artikel + Transport in jede Option der Gruppen
  for r in select o.id, substring(o.optionsgruppe_name from '(\d+)')::int liter from auswahloption o where o.auswahlfeld_id = af_k loop
    delete from ressourcenzeile where option_id = r.id and artikel_id in (old1, old2);
    select to_jsonb(rz) into tpl from ressourcenzeile rz join artikel a on a.id=rz.artikel_id where rz.option_id=r.id and a.bezeichnung like 'Pauschale Hilfsmaterial%' order by rz.reihenfolge limit 1;
    if tpl is null then raise exception 'Vorlagezeile fehlt in Option %', r.id; end if;
    update ressourcenzeile set reihenfolge = reihenfolge + 2 where option_id = r.id and reihenfolge >= 3;
    insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile, tpl || jsonb_build_object('id', gen_random_uuid(), 'artikel_id', (komfort->>r.liter::text)::uuid,
      'kategorie', 'material', 'menge_ausdruck', '{"lit": 1, "_einheit": "Stk."}'::jsonb, 'reihenfolge', 3, 'notiz', null, 'mindestmenge', null, 'verschnitt_prozent', null))).*;
    insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile, tpl || jsonb_build_object('id', gen_random_uuid(), 'artikel_id', case when r.liter >= 7500 then a_t_ab else a_t_bis end,
      'kategorie', 'logistik', 'menge_ausdruck', '{"lit": 1, "_einheit": "Stk."}'::jsonb, 'reihenfolge', 4, 'notiz', 'Transport ab HGC, ohne Abladen', 'mindestmenge', null, 'verschnitt_prozent', null))).*;
  end loop;

  -- Umbenennen
  update teilschritt set name = 'Regenwassertank Garten-Komfort' where id = ts_k;
  update auswahlfeld set name = 'Regenwassertank Garten-Komfort' where id = af_k;

  -- Haus Professionell: Kopie ab 3000 L
  insert into teilschritt select (jsonb_populate_record(null::teilschritt, to_jsonb(t) || jsonb_build_object('id', ts_p, 'name', 'Regenwassertank Haus Professionell', 'reihenfolge', t.reihenfolge + 1))).* from teilschritt t where t.id = ts_k;
  insert into auswahlfeld select (jsonb_populate_record(null::auswahlfeld, to_jsonb(f) || jsonb_build_object('id', af_p, 'teilschritt_id', ts_p, 'name', 'Regenwassertank Haus Professionell'))).* from auswahlfeld f where f.id = af_k;
  for r in select o.*, substring(o.optionsgruppe_name from '(\d+)')::int liter from auswahloption o where o.auswahlfeld_id = af_k and substring(o.optionsgruppe_name from '(\d+)')::int >= 3000 order by o.reihenfolge loop
    g := r.optionsgruppe_id::text;
    if g is not null and not (gmap ? g) then gmap := gmap || jsonb_build_object(g, gen_random_uuid()); end if;
    new_o := gen_random_uuid();
    insert into auswahloption select (jsonb_populate_record(null::auswahloption, to_jsonb(r) - 'liter' || jsonb_build_object('id', new_o, 'auswahlfeld_id', af_p,
      'optionsgruppe_id', case when g is null then null else gmap->>g end))).*;
    for z in select * from ressourcenzeile where option_id = r.id order by reihenfolge loop
      insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile, to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', new_o,
        'teilschritt_id', case when z.teilschritt_id is null then null else ts_p end,
        'artikel_id', case when z.artikel_id = (komfort->>r.liter::text)::uuid then (prof->>r.liter::text)::uuid else z.artikel_id end))).*;
    end loop;
  end loop;
end $$;
