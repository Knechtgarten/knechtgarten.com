-- ============================================================================
-- Pflege-Tool: Standardarbeiten mehrmals pro Jahr (Entwurf Wochenplanung v2)
--
-- pflege_arbeit.standard_kw (eine Woche)  -> standard_kws (1..n Wochen)
-- pflege_kunde_arbeit.kw (eine Woche)     ->
--   Standardarbeit: nur die Abweichung vom Standard (kws_plus / kws_minus),
--                   damit Kunden spaetere Standard-Aenderungen mitziehen
--   Zusatzarbeit:   eigene Wochenliste (kws)
-- Bestehende Werte werden umgerechnet.
-- ============================================================================

-- Standardarbeiten
alter table pflege_arbeit add column standard_kws integer[] not null default '{}';
update pflege_arbeit set standard_kws = array[standard_kw] where standard_kw is not null;
alter table pflege_arbeit drop column standard_kw;
alter table pflege_arbeit add constraint pflege_arbeit_standard_kws_check
  check (standard_kws <@ '{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53}'::integer[]);

-- Arbeiten beim Kunden
alter table pflege_kunde_arbeit add column kws_plus integer[] not null default '{}';
alter table pflege_kunde_arbeit add column kws_minus integer[] not null default '{}';
alter table pflege_kunde_arbeit add column kws integer[] not null default '{}';

-- Standardarbeit mit uebersteuerter KW: Standard weglassen, eigene KW dazu
update pflege_kunde_arbeit ka
   set kws_plus = array[ka.kw],
       kws_minus = (select a.standard_kws from pflege_arbeit a where a.id = ka.arbeit_id)
 where ka.arbeit_id is not null and ka.kw is not null
   and not (array[ka.kw] <@ (select a.standard_kws from pflege_arbeit a where a.id = ka.arbeit_id));
-- Zusatzarbeit: Wochenliste
update pflege_kunde_arbeit set kws = array[kw] where arbeit_id is null and kw is not null;

alter table pflege_kunde_arbeit drop constraint pflege_kunde_arbeit_check;
alter table pflege_kunde_arbeit drop column kw;
alter table pflege_kunde_arbeit add constraint pflege_kunde_arbeit_check
  check (arbeit_id is not null or titel is not null);
alter table pflege_kunde_arbeit add constraint pflege_kunde_arbeit_kws_check
  check (kws <@ '{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53}'::integer[] and kws_plus <@ '{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53}'::integer[] and kws_minus <@ '{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53}'::integer[]);
