alter table lieferant_datenabgleich add column crawling_modus text not null default 'ergaenzen'
  check (crawling_modus in ('ergaenzen', 'nurabgleich', 'ganzershop'));
