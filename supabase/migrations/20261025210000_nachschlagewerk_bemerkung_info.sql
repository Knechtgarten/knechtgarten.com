-- Nachschlagewerk Logbuch: keine eigene Bemerkung mehr – bestehende Bemerkungen ans Info (arbeit) anhängen.
update public.wissen_service_erledigt
  set arbeit = arbeit || ' · ' || trim(bemerkung), bemerkung = null
  where nullif(trim(bemerkung), '') is not null;
