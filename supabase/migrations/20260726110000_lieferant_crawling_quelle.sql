-- "Ganzer Shop" wandert aus dem crawling_modus (Ergaenzen/Nur Abgleich) heraus
-- in eine eigene, unabhaengige Spalte: crawling_modus entscheidet nur noch, ob
-- neue Artikel vorgeschlagen werden, crawling_quelle entscheidet, ob dabei die
-- Merklisten oder der ganze Shop durchsucht werden.
update lieferant_datenabgleich set crawling_modus = 'ergaenzen' where crawling_modus = 'ganzershop';

alter table lieferant_datenabgleich drop constraint if exists lieferant_datenabgleich_crawling_modus_check;
alter table lieferant_datenabgleich add constraint lieferant_datenabgleich_crawling_modus_check
  check (crawling_modus in ('ergaenzen', 'nurabgleich'));

alter table lieferant_datenabgleich add column crawling_quelle text not null default 'merkliste'
  check (crawling_quelle in ('merkliste', 'ganzershop'));
