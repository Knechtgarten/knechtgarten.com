-- Mail-Assistent: mehrere Ansprechpartner pro externer Firma, jeder mit
-- eigenem Namen und eigener Anrede (Du/Sie) - loest das gestern eingefuehrte
-- Einzelfeld anrede/anrede_name auf mailassistent_externe_kontakte ab (bleibt
-- unbenutzt in der DB stehen). Uebernimmt einen evtl. schon erfassten
-- Namen/Anrede als ersten Ansprechpartner, damit nichts verloren geht.
create table if not exists mailassistent_externe_kontakt_person (
  id uuid primary key default gen_random_uuid(),
  kontakt_id uuid not null references mailassistent_externe_kontakte(id) on delete cascade,
  name text not null default '',
  anrede text,
  reihenfolge integer not null default 0
);

insert into mailassistent_externe_kontakt_person (kontakt_id, name, anrede, reihenfolge)
select id, anrede_name, anrede, 0
from mailassistent_externe_kontakte k
where anrede_name is not null and trim(anrede_name) <> ''
  and not exists (
    select 1 from mailassistent_externe_kontakt_person p where p.kontakt_id = k.id
  );
