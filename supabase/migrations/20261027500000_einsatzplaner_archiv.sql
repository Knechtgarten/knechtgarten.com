-- Einsatzplaner: Archiv für Personen, die nicht mehr da sind
-- archiviert_am  Datum, an dem die Person ins Archiv kam (Gruppe «Archiv» ganz unten, nach Jahr unterteilt).
--                Archivierte Personen sind aktiv = false; zurückholen = Datum leeren, aktiv = true.
alter table planer_person add column if not exists archiviert_am date null;
-- Bisher inaktive Personen kommen ins Archiv, unter dem Jahr ihres letzten Eintrags
update planer_person p set archiviert_am = coalesce((select max(e.ende)::date from planer_einsatz e where e.person_id = p.id), p.erstellt_am::date)
  where not p.aktiv and p.archiviert_am is null;
