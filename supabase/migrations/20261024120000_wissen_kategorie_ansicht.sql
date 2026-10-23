-- ============================================================================
-- Wissen & Geräte: Anzeige pro Kategorie für die normale Ansicht UND die QR-Ansicht.
-- abschnitt_reihe = Reihenfolge aller Teile, normal_aus / qr_aus = ausgeblendete Teile.
-- Ersetzt qr_abschnitte und das Häkchen mit_service (mit_service wird vom Tool nachgeführt:
-- false, sobald in der normalen Ansicht beide Service-Teile aus sind – das liest der Einsatzplaner).
-- ============================================================================
alter table wissen_kategorie
  add column if not exists abschnitt_reihe text[],
  add column if not exists normal_aus text[] not null default '{}',
  add column if not exists qr_aus text[] not null default '{}';

-- bisherige QR-Auswahl übernehmen: gewählte zuerst, alle übrigen beim Scannen ausgeblendet
with alle(k) as (select array['x_angaben','x_service','x_notizen','notizen','steck','anw','service','kontakte','docs'])
update wissen_kategorie set
  abschnitt_reihe = qr_abschnitte || array(select t from unnest((select k from alle)) t where not t = any(qr_abschnitte)),
  qr_aus = array(select t from unnest((select k from alle)) t where not t = any(qr_abschnitte))
where qr_abschnitte is not null;

-- Kategorien ohne Service: beide Service-Teile überall aus
update wissen_kategorie set
  normal_aus = array['x_service','service'],
  qr_aus = array(select distinct t from unnest(qr_aus || array['x_service','service']) t)
where mit_service = false;
