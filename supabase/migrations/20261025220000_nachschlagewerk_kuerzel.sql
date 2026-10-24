-- Nachschlagewerk Kurzinfo: Kürzel wie bei Text Blaze (z. B. «/mwst»), pro Kürzel nur ein Eintrag.
alter table public.wissen_eintrag add column if not exists kuerzel text;
create unique index if not exists wissen_eintrag_kuerzel_uni on public.wissen_eintrag (lower(kuerzel))
  where kuerzel is not null and archiviert_am is null;
