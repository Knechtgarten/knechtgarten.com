-- Nachschlagewerk: Service-Liste pro Stück als Logbuch mit Spalte «Art» (Service · Reparatur · Prüfung · Kontrolle).
-- Gilt für erledigte Einträge und für die geplanten Arbeiten im Serviceplan.
alter table public.wissen_service_erledigt add column if not exists art text not null default 'Service'
  check (art in ('Service', 'Reparatur', 'Prüfung', 'Kontrolle'));
alter table public.wissen_service add column if not exists art text not null default 'Service'
  check (art in ('Service', 'Reparatur', 'Prüfung', 'Kontrolle'));

-- bisherige Stand-Zeilen werden Kontrollen («km-Kontrolle» bzw. «Stunden-Kontrolle»)
update public.wissen_service_erledigt
  set art = 'Kontrolle', arbeit = case when stand ~ '\sh$' then 'Stunden-Kontrolle' else 'km-Kontrolle' end
  where service_id is null and arbeit = 'Stand';
