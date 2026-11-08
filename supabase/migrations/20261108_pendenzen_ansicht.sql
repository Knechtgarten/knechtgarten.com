-- Pendenzen pro Gruppe: «buero» = ganzes Pendenzen-Tool, «mitarbeiter» = nur Wann? (Heute/Woche/Monat), Sammelbox, Dauernde Notizen, Archivieren
alter table recht_gruppe add column if not exists pendenzen_ansicht text not null default 'buero'
  check (pendenzen_ansicht in ('buero', 'mitarbeiter'));
update recht_gruppe set pendenzen_ansicht = 'mitarbeiter' where schluessel in ('hilf', 'temp', 'schnupper', 'va_bau');
