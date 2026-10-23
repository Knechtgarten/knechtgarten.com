begin;

-- ============================================================================
-- Wissen & Geräte: Haupteintrag mit Exemplaren (wie Pflegekategorien beim Kunden)
--
-- wissen_eintrag   = Haupteintrag (Titel, Foto, Kategorie, Bereiche, Anwendung,
--                    allgemeiner Steckbrief, Kontakte, Dokumente, Service-Arbeiten)
-- wissen_exemplar  = die einzelne Maschine (Nummer, Zuständig, eigener Steckbrief,
--                    Verwaltung, QR-Etikette, Einsatzplaner, erledigte Services)
--
-- Service: nur noch Arbeiten pro Haupteintrag (kein Standard pro Geräteart, keine
-- Abweichungen). Die Wochen sind Startwochen und gelten für alle Exemplare.
-- Erledigt wird pro Exemplar. Notizen und Dateien: ohne exemplar_id = gilt für alle.
--
-- Bestand: gleiche Geräte werden zusammengelegt (Liste unten), alle anderen werden
-- ein Haupteintrag mit einem Exemplar. QR-Nummern bleiben (Etiketten gelten weiter).
-- ============================================================================

create table wissen_exemplar (
  id uuid primary key default gen_random_uuid(),
  eintrag_id uuid not null references wissen_eintrag(id) on delete cascade,
  qr_nr int not null unique default nextval('wissen_qr_nr_seq'),
  nummer text null,                        -- T1.1, BE-424586, 2.1 ... (Tab-Name)
  zustaendig text null,
  steckbrief jsonb not null default '[]',  -- nur was bei diesem Exemplar anders ist (Kontrollschild, Jahrgang ...)
  verwaltung jsonb not null default '[]',  -- nur Buero, nicht beim QR-Scan
  planer_ressource_id uuid null unique references planer_ressource(id) on delete set null,
  sortierung int not null default 0,
  archiviert_am timestamptz null,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create index wissen_exemplar_eintrag_idx on wissen_exemplar (eintrag_id);
create trigger wissen_exemplar_touch before update on wissen_exemplar for each row execute function wissen_touch();
alter table wissen_exemplar enable row level security;
create policy wissen_exemplar_lesen on wissen_exemplar for select using (ist_eingeloggter_benutzer());
create policy wissen_exemplar_buero on wissen_exemplar for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

alter table wissen_notiz add column exemplar_id uuid null references wissen_exemplar(id) on delete cascade;
alter table wissen_datei add column exemplar_id uuid null references wissen_exemplar(id) on delete cascade;
alter table wissen_service_erledigt add column exemplar_id uuid null references wissen_exemplar(id) on delete cascade;
alter table wissen_service add column im_planer boolean not null default true;
alter table wissen_service add column anleitung_html text null;

do $$
declare
  ind constant text := '^(Anschaffungsjahr|Team|Kontrollschild|km |Fahrzeugprüfung|Betriebsstunden|Stammfahrer|Baujahr|Bemerkung|Seriennummer)';
  g record; e record; h uuid; ex uuid; gemein jsonb; nr text; n int;
begin
  if exists (select 1 from wissen_exemplar) then
    raise notice 'Exemplare gibt es schon - Umstellung übersprungen';
    return;
  end if;

  -- Gruppen: gleiche Geräte, die ein Haupteintrag mit mehreren Exemplaren werden
  create temp table gruppe (re text, titel text, unter text) on commit drop;
  insert into gruppe values
    ('^Heckenschere T', 'Heckenschere', 'Stihl HSA 100'),
    ('^Stabheckenschere T', 'Stabheckenschere', 'Stihl HLA 86'),
    ('^Laubbläser T', 'Laubbläser', 'Stihl BGA 86'),
    ('^Motorsense T', 'Motorsense', null),
    ('^Motorsäge Akku T', 'Motorsäge Akku', null),
    ('^Motorsäge T', 'Motorsäge', null),
    ('^Raupenbagger 2\.', 'Raupenbagger 2 t', 'Takeuchi TB219'),
    ('^Raupenbagger 3\.', 'Raupenbagger 3.5 t', 'Takeuchi TB228'),
    ('^Raupenbagger 9\.', 'Raupenbagger 9 t', 'Takeuchi TB290'),
    ('^Raupendumper gross', 'Raupendumper gross', 'Rufener RK085 DM'),
    ('^Raupendumper R\.[34]$', 'Raupendumper', 'Rufener RK049 DM S'),
    ('^Lieferwagen BE', 'Lieferwagen', 'Mitsubishi Fuso'),
    ('^Personenwagen BE', 'Personenwagen', null),
    ('^Baustellenanhänger', 'Baustellenanhänger', 'Niederberger'),
    ('^Grabenstampfer', 'Grabenstampfer', 'Wacker'),
    ('^Vibroplatte [2-5]$', 'Vibroplatte', 'Wacker'),
    ('^Greifer 2 t', 'Greifer 2 t', 'Martin'),
    ('^Greifer 3\.5 t', 'Greifer 3.5 t', 'Martin'),
    ('^Rasenmäher RMA', 'Rasenmäher', 'Stihl'),
    ('^Vertikutierer \d', 'Vertikutierer', 'ELIET 50L');

  create temp table zuordnung on commit drop as
    select w.id, w.qr_nr, (select gr.titel from gruppe gr where w.titel ~ gr.re limit 1) as gtitel
    from wissen_eintrag w where w.typ = 'geraet' and w.archiviert_am is null;

  -- Jede Gruppe (bzw. jedes einzelne Gerät): kleinste QR-Nr. wird der Haupteintrag
  for g in
    select coalesce(z.gtitel, z.id::text) as k, z.gtitel, array_agg(z.id order by z.qr_nr) as ids
    from zuordnung z group by 1, 2
  loop
    h := g.ids[1];
    -- gemeinsamer Steckbrief: Zeilen, die alle Geräte der Gruppe gleich haben und nicht individuell sind
    select coalesce(jsonb_agg(r), '[]') into gemein
    from jsonb_array_elements((select steckbrief from wissen_eintrag where id = h)) r
    where not (r->>'label' ~ ind)
      and not exists (select 1 from wissen_eintrag w2 where w2.id = any(g.ids) and not (w2.steckbrief @> jsonb_build_array(r)));

    n := 0;
    for e in select * from wissen_eintrag where id = any(g.ids) order by qr_nr loop
      n := n + 1;
      nr := coalesce(e.nummer, substring(e.titel from '\((\d+)\)$'), substring(e.titel from '(RMA \d+)$'),
                     case when g.gtitel is not null then substring(e.titel from ' (\d+)$') end);
      insert into wissen_exemplar (eintrag_id, qr_nr, nummer, zustaendig, steckbrief, verwaltung, planer_ressource_id, sortierung)
      values (h, e.qr_nr, nr, e.zustaendig,
        coalesce((select jsonb_agg(r) from jsonb_array_elements(e.steckbrief) r
                  where not (gemein @> jsonb_build_array(r))
                    and not (r->>'label' in ('Team', 'Stammfahrer') and r->>'wert' = coalesce(e.zustaendig, ''))), '[]'),
        e.verwaltung, e.planer_ressource_id, n * 10)
      returning id into ex;
      -- Notizen und Dateien des Geraets gehoeren zu seinem Exemplar
      update wissen_notiz set eintrag_id = h, exemplar_id = ex where eintrag_id = e.id;
      update wissen_datei set eintrag_id = h, exemplar_id = ex where eintrag_id = e.id;
      update wissen_datei set auch_bei = array_replace(auch_bei, e.id, h) where e.id = any(auch_bei);
      update wissen_kontakt set eintrag_id = h where eintrag_id = e.id;
      update wissen_service_erledigt set eintrag_id = h, exemplar_id = ex where eintrag_id = e.id;
      update wissen_service set eintrag_id = h where eintrag_id = e.id;
      update wissen_eintrag set gehoert_zu_id = h where gehoert_zu_id = e.id and id <> h;
      if e.id <> h then
        update wissen_eintrag set planer_ressource_id = null where id = e.id;
        delete from wissen_eintrag where id = e.id;
      end if;
    end loop;

    update wissen_eintrag set
      titel = coalesce(g.gtitel, titel),
      untertitel = case when g.gtitel is not null then (select unter from gruppe where titel = g.gtitel) else untertitel end,
      steckbrief = gemein, planer_ressource_id = null
    where id = h;
  end loop;

  -- Standardarbeiten pro Geraeteart -> Arbeit bei jedem Haupteintrag dieser Geraeteart
  insert into wissen_service (eintrag_id, arbeit, kws, zeit, wer, sortierung)
  select w.id, s.arbeit, s.kws, s.zeit, s.wer, s.sortierung
  from wissen_service s join wissen_eintrag w on w.geraeteart = s.geraeteart
  where s.geraeteart is not null;
  delete from wissen_service where geraeteart is null and eintrag_id is null;
  delete from wissen_service where geraeteart is not null;
end $$;

-- Aufräumen: was jetzt am Exemplar hängt bzw. nicht mehr gebraucht wird
alter table wissen_service drop constraint if exists wissen_service_check;
drop index if exists wissen_service_art_idx;
alter table wissen_service drop column geraeteart;
alter table wissen_service alter column eintrag_id set not null;
drop table wissen_service_abw;
alter table wissen_service_erledigt alter column exemplar_id set not null;
create index wissen_service_erledigt_exemplar_idx on wissen_service_erledigt (exemplar_id);
create index wissen_notiz_exemplar_idx on wissen_notiz (exemplar_id);
alter table wissen_eintrag drop column nummer;
alter table wissen_eintrag drop column zustaendig;
alter table wissen_eintrag drop column verwaltung;
alter table wissen_eintrag drop column planer_ressource_id;
comment on column wissen_eintrag.geraeteart is 'Gruppe in der Tabelle «Fahrzeuge & Maschinen» (z.B. Lieferwagen)';
comment on column wissen_eintrag.qr_nr is 'Nur noch für Produkte/Wissen. Geräte: QR pro Exemplar (wissen_exemplar.qr_nr)';

-- ----------------------------------------------------------------------------
-- Zusammenlegen: alle Exemplare (mit Notizen, Dateien, Erledigt) von «quelle» zu
-- «ziel». Arbeiten mit gleichem Namen werden zusammengeführt, neue übernommen.
-- ----------------------------------------------------------------------------
create or replace function wissen_zusammenlegen(ziel uuid, quelle uuid)
returns void language plpgsql security invoker as $$
declare s record; neu uuid;
begin
  if not ist_buero_oder_admin() then raise exception 'Nur Büro'; end if;
  if ziel = quelle then raise exception 'Gleicher Eintrag'; end if;
  for s in select * from wissen_service where eintrag_id = quelle loop
    select id into neu from wissen_service where eintrag_id = ziel and lower(arbeit) = lower(s.arbeit) limit 1;
    if neu is null then update wissen_service set eintrag_id = ziel where id = s.id;
    else update wissen_service_erledigt set service_id = neu where service_id = s.id; delete from wissen_service where id = s.id; end if;
  end loop;
  update wissen_exemplar set eintrag_id = ziel, sortierung = sortierung + 1000 where eintrag_id = quelle;
  update wissen_notiz set eintrag_id = ziel where eintrag_id = quelle;
  update wissen_datei set eintrag_id = ziel where eintrag_id = quelle;
  update wissen_datei set auch_bei = array_replace(auch_bei, quelle, ziel) where quelle = any(auch_bei);
  update wissen_datei set auch_bei = array_remove(auch_bei, ziel) where eintrag_id = ziel and ziel = any(auch_bei);
  update wissen_kontakt set eintrag_id = ziel where eintrag_id = quelle;
  update wissen_service_erledigt set eintrag_id = ziel where eintrag_id = quelle;
  update wissen_eintrag set gehoert_zu_id = ziel where gehoert_zu_id = quelle;
  update wissen_eintrag w set anwendung_html = nullif(concat_ws('<hr>', nullif(w.anwendung_html, ''), nullif(q.anwendung_html, '')), '')
    from wissen_eintrag q where w.id = ziel and q.id = quelle;
  delete from wissen_eintrag where id = quelle;
end; $$;

-- ----------------------------------------------------------------------------
-- Herauslösen: Exemplar wird ein eigener Haupteintrag (Kopie von Titel, Steckbrief,
-- Anwendung, Arbeiten, Kontakten). Seine Notizen, Dateien und Erledigt ziehen mit.
-- ----------------------------------------------------------------------------
create or replace function wissen_herausloesen(ex uuid)
returns uuid language plpgsql security invoker as $$
declare alt uuid; neu uuid; s record; ns uuid;
begin
  if not ist_buero_oder_admin() then raise exception 'Nur Büro'; end if;
  select eintrag_id into alt from wissen_exemplar where id = ex;
  insert into wissen_eintrag (typ, titel, untertitel, kategorie_id, bereich_ids, tags, geraeteart, steckbrief, anwendung_html, gehoert_zu_id, titelfoto_pfad, erstellt_von)
  select typ, titel || ' ' || coalesce((select nummer from wissen_exemplar where id = ex), ''), untertitel, kategorie_id, bereich_ids, tags, geraeteart, steckbrief, anwendung_html, gehoert_zu_id, null, auth.uid()
  from wissen_eintrag where id = alt returning id into neu;
  for s in select * from wissen_service where eintrag_id = alt loop
    insert into wissen_service (eintrag_id, arbeit, kws, zeit, wer, sortierung, im_planer, anleitung_html)
    values (neu, s.arbeit, s.kws, s.zeit, s.wer, s.sortierung, s.im_planer, s.anleitung_html) returning id into ns;
    update wissen_service_erledigt set service_id = ns, eintrag_id = neu where exemplar_id = ex and service_id = s.id;
  end loop;
  insert into wissen_kontakt (eintrag_id, art, lieferant_id, kunde_id, name, rolle, sortierung)
  select neu, art, lieferant_id, kunde_id, name, rolle, sortierung from wissen_kontakt where eintrag_id = alt;
  update wissen_datei set auch_bei = array_append(auch_bei, neu) where eintrag_id = alt and exemplar_id is null and bereich = 'dokument';
  update wissen_exemplar set eintrag_id = neu where id = ex;
  update wissen_notiz set eintrag_id = neu where exemplar_id = ex;
  update wissen_datei set eintrag_id = neu where exemplar_id = ex;
  update wissen_service_erledigt set eintrag_id = neu where exemplar_id = ex;
  return neu;
end; $$;

commit;
