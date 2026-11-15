-- Neuer Offertentyp «Easy»: fertige Vorlagen (aus Easybill übernommen), Klick im Offerten-Blatt fügt die Zeilen ein, nichts wird berechnet.
alter table public.offertentyp drop constraint if exists offertentyp_berechnungsmodell_check;
alter table public.offertentyp add constraint offertentyp_berechnungsmodell_check check (berechnungsmodell = any (array['formel','tagessatz','artikel','easy']));
insert into public.offertentyp (name, berechnungsmodell, reihenfolge, ausgeblendet)
select 'Easy', 'easy', 4, false where not exists (select 1 from public.offertentyp where berechnungsmodell = 'easy');

create table if not exists public.easy_vorlage (
  id uuid primary key default gen_random_uuid(),
  offertentyp_id uuid references public.offertentyp(id) on delete cascade,
  name text not null,
  reihenfolge integer not null default 0,
  hinweis_text text,           -- kommt beim Einfügen in «Hinweise zu gewählten Optionen»
  quelle text,                 -- z. B. «Easybill 26-17876»
  ausgeblendet boolean not null default false,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create table if not exists public.easy_vorlage_zeile (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references public.easy_vorlage(id) on delete cascade,
  reihenfolge integer not null default 0,
  typ text not null default 'position' check (typ in ('position','text')),
  kategorie text not null default 'material',
  artikel_id uuid references public.artikel(id) on delete set null,  -- mit Artikel: Preis beim Einfügen aktuell aus dem Artikelstamm
  bezeichnung text not null default '',
  menge numeric not null default 0,
  einheit text,
  preis numeric not null default 0,
  optional boolean not null default false
);
create index if not exists easy_vorlage_zeile_vorlage_idx on public.easy_vorlage_zeile(vorlage_id);
alter table public.easy_vorlage enable row level security;
alter table public.easy_vorlage_zeile enable row level security;
drop policy if exists easy_vorlage_alle on public.easy_vorlage;
create policy easy_vorlage_alle on public.easy_vorlage for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
drop policy if exists easy_vorlage_zeile_alle on public.easy_vorlage_zeile;
create policy easy_vorlage_zeile_alle on public.easy_vorlage_zeile for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- 5 Vorlagen aus Easybill (Kunden «Vorlagen Bau 2026» / «Vorlagen Wasser 2026»)
with v as (insert into public.easy_vorlage (offertentyp_id, name, reihenfolge, hinweis_text, quelle) values ((select id from offertentyp where berechnungsmodell='easy' limit 1), 'Vorlage Budget kompakt', 1, '', 'Easybill 25-17288') returning id)
insert into public.easy_vorlage_zeile (vorlage_id, reihenfolge, typ, kategorie, artikel_id, bezeichnung, menge, einheit, preis, optional) values
((select id from v), 1, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000010'), 'Polier / Vorarbeiter', 0, 'Std', 102, false),
((select id from v), 2, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000005'), 'Gartenarbeiter', 0, 'Std', 82, false),
((select id from v), 3, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000030'), 'Projektleiter', 0, 'Std', 152, false),
((select id from v), 4, 'position', 'logistik', null, 'Transportaufwand 3,5t / 3 Seiten Kipper', 0, 'Std', 108, false),
((select id from v), 5, 'position', 'logistik', null, 'Transportaufwand 3,5t / 3 Seiten Kipper', 1, 'Budget', 0, false),
((select id from v), 6, 'position', 'maschine', null, 'Motorgeräte', 1, 'P', 0, false),
((select id from v), 7, 'position', 'maschine', null, 'Baumaschinen', 1, 'Budget', 0, false),
((select id from v), 8, 'position', 'logistik', null, 'Kranarbeiten
- Kran 3-Achser              = 238.-/Std
- Kran 4-Achser              = 294.-/Std
- Kran 5-Achser              = 348.-/Std
- Kran 5-Achser Spezial  = 394.-/Std', 1, 'Budget', 0, false),
((select id from v), 9, 'position', 'logistik', null, 'Transporte, Mulden, Betonpumpe, Förderband', 1, 'Budget', 0, false),
((select id from v), 10, 'position', 'material', null, 'Materialbudget für die im Arbeitsbeschrieb vorgesehenen Arbeiten.', 1, 'Budget', 0, false);
with v as (insert into public.easy_vorlage (offertentyp_id, name, reihenfolge, hinweis_text, quelle) values ((select id from offertentyp where berechnungsmodell='easy' limit 1), 'Vorlage Budget ausführlich inkl. Transporte', 2, '', 'Easybill 25-17266') returning id)
insert into public.easy_vorlage_zeile (vorlage_id, reihenfolge, typ, kategorie, artikel_id, bezeichnung, menge, einheit, preis, optional) values
((select id from v), 1, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000010'), 'Polier / Vorarbeiter', 0, 'Std', 102, false),
((select id from v), 2, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000005'), 'Gartenarbeiter', 0, 'Std', 82, false),
((select id from v), 3, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000030'), 'Projektleiter', 0, 'Std', 152, false),
((select id from v), 4, 'position', 'logistik', null, 'Transportaufwand 3,5t / 3 Seiten Kipper', 0, 'Std', 108, false),
((select id from v), 5, 'position', 'logistik', null, 'Transportaufwand 3,5t / 3 Seiten Kipper', 1, 'Budget', 0, false),
((select id from v), 6, 'position', 'maschine', null, 'Motorgeräte', 1, 'P', 0, false),
((select id from v), 7, 'position', 'maschine', null, 'Baumaschinen', 1, 'Budget', 0, false),
((select id from v), 8, 'position', 'maschine', null, 'Kernbohrgerät pro Bohrung bis D = 1 bis 5cm', 0, 'Stk', 58, false),
((select id from v), 9, 'position', 'maschine', null, 'Kernbohrgerät pro Bohrung  D = 5.5 bis 25cm', 0, 'Stk', 128, false),
((select id from v), 10, 'position', 'logistik', null, 'Kran
- Kran 3-Achser              = 238.-/Std
- Kran 4-Achser              = 294.-/Std
- Kran 5-Achser              = 348.-/Std
- Kran 5-Achser Spezial  = 394.-/Std', 1, 'Budget', 0, false),
((select id from v), 11, 'position', 'logistik', null, 'Transporte, Mulden, Betonpumpe, Förderband,', 1, 'Budget', 0, false),
((select id from v), 12, 'position', 'material', null, 'Materialbudget für die im Arbeitsbeschrieb vorgesehenen Arbeiten.', 1, 'Budget', 0, false),
((select id from v), 13, 'position', 'material', null, 'Erdarbeiten und Grünflächen Materialaufwand Budgetbetrag', 1, 'Budget', 0, false),
((select id from v), 14, 'position', 'material', null, 'Fundationen Materialaufwand Budgetbetrag', 1, 'Budget', 0, false),
((select id from v), 15, 'position', 'material', null, 'Hartflächen, Beläge, Natursteinarbeiten Materialaufwand Budgetbetrag', 1, 'Budget', 0, false),
((select id from v), 16, 'position', 'material', null, 'Metallelemente', 1, 'Budget', 0, false),
((select id from v), 17, 'position', 'material', null, 'Material Leitungen, Schächte, Rinnen Materialaufwand Budgetbetrag', 1, 'Budget', 0, false),
((select id from v), 18, 'position', 'material', null, 'Substrat
- Dach und Trogerde intensiv 30L               12.50 Fr/Sack
- Dach und Trogerde intensiv im Big Bag    312.-/m3', 1, 'Budget', 0, false),
((select id from v), 19, 'position', 'material', null, 'Natursteinplatten', 1, 'm2', 0, false),
((select id from v), 20, 'position', 'material', null, 'Stahlelemente Metallbaumanufaktur laut Skizze', 1, 'Stk', 0, false),
((select id from v), 21, 'position', 'material', null, 'Material Creabeton', 1, 'Stk', 0, false),
((select id from v), 22, 'position', 'material', null, 'Beton Grossmengen ab 2m3', 1, 'm3', 0, false),
((select id from v), 23, 'position', 'material', null, 'Kies Grossmengen ab 5m3
- Rundkies
- Koffermaterial', 1, 'm3', 0, false);
with v as (insert into public.easy_vorlage (offertentyp_id, name, reihenfolge, hinweis_text, quelle) values ((select id from offertentyp where berechnungsmodell='easy' limit 1), 'Beispielofferte Belagsreinigung bis 30m2 Region Thun', 3, '- Wetterschenkel, Metallteile und Geländer abdecken. Plattenbelag/Holzdeck mit Arvox Spezialreiniger reinigen. Bei stark verschmutzten Fläche wird ein zweiter Durchgang gemacht.
- Hinweis: Gesamtes Mobiliar vorgängig beiseite stellen und am Schluss der Arbeiten wieder platzieren = bauseits. Moos und Unkrautbewuchs vorgängig entfernen = bauseits
- Dies ist eine Beispielofferte bis 30m2 Fläche in der Region Thun. Bei grösseren Flächen, längeren Anfahrtswegen oder erschwerter Zugänglichkeit der Belagsfläche erhöht sich der Preis entsprechend.', 'Easybill 26-17649') returning id)
insert into public.easy_vorlage_zeile (vorlage_id, reihenfolge, typ, kategorie, artikel_id, bezeichnung, menge, einheit, preis, optional) values
((select id from v), 1, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000010'), 'Polier / Vorarbeiter', 5, 'Std', 102, false),
((select id from v), 2, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000005'), 'Gartenarbeiter', 5, 'Std', 82, false),
((select id from v), 3, 'position', 'logistik', (select id from artikel where artikelnummer_knecht='KNECHT_000101'), 'Lieferwagen', 0.75, 'Std', 108, false),
((select id from v), 4, 'position', 'maschine', null, 'Reinigungsmaschinen Rotowash', 1, 'Stk', 128, false),
((select id from v), 5, 'position', 'material', null, 'Spezialreiniger Naturstein / Beton 2K
2x1Liter
Grossmenge ab 5L (2x5L)', 5, 'Stk', 29.5, false),
((select id from v), 6, 'position', 'material', null, 'Spezialreiniger Naturstein / Beton 2K
2x1Liter
Kleinmenge bis 4L (2x4L)', 1, 'Stk', 47.6, true),
((select id from v), 7, 'position', 'material', null, 'Spezialreiniger Holz 2K
2x1Liter
Grossmenge ab 5 Liter (2x5L)', 1, 'Stk', 38.8, true),
((select id from v), 8, 'position', 'material', null, 'Spezialreiniger Holz 2K
2x1Liter
Kleinmenge bis 4 Liter (2x4L)', 1, 'Stk', 53.9, true),
((select id from v), 9, 'position', 'material', null, 'Abdeckmaterial für Wetterschenkel, Metallteile, Geländer', 1, 'Stk', 35, false);
with v as (insert into public.easy_vorlage (offertentyp_id, name, reihenfolge, hinweis_text, quelle) values ((select id from offertentyp where berechnungsmodell='easy' limit 1), 'Teich Reinigung mit Fräsen', 4, '- Wände und Boden fräsen. Nach einer Absetzzeit Schlamm und Sedimente absaugen und abführen. Pflanzen im Regenerationsbereich zurückschneiden falls erwünscht. Am Ende der Arbeiten Teich wieder mit Wasser befüllen.
- Hinweis: - Die Reinigung geschieht in zwei Einsätzen. Zwischen den Einsätzen ist eine Woche Abstand (Absetzzeit). - Allfällige Übernahme von  Kosten für Abwasser und Frischwasser = bauseits (nicht eingerechnet).', 'Easybill 26-17876') returning id)
insert into public.easy_vorlage_zeile (vorlage_id, reihenfolge, typ, kategorie, artikel_id, bezeichnung, menge, einheit, preis, optional) values
((select id from v), 1, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000016'), 'Servicetechniker Wassergärten', 15, 'Std', 132, false),
((select id from v), 2, 'position', 'logistik', null, 'Transportaufwand 3,5t / 3 Seiten Kipper', 2, 'Std', 108, false),
((select id from v), 3, 'position', 'maschine', null, 'Spezialmaschinen und Geräte Wasserpflege wie:
Sedimentsauger mit Reinigungszylinder und Zusatzgeräte, Spezial Unterwasser Flächenreiniger
inkl. Hochdruckreiniger und Zusatzmaterial, Mobiler vollautomatischer Vliesfilter inkl. Vliesverbrauch zur Rückführung des abgesaugten Wassers von Hochdruckgerät oder Sedimentsauger Pro Einsatz', 1, 'Stk', 228, false),
((select id from v), 4, 'position', 'material', null, 'Materialbudget für die im Arbeitsbeschrieb vorgesehenen Arbeiten.', 1, 'Budget', 60, false);
with v as (insert into public.easy_vorlage (offertentyp_id, name, reihenfolge, hinweis_text, quelle) values ((select id from offertentyp where berechnungsmodell='easy' limit 1), 'Sanierung Divers', 5, '- Arbeitsbeschrieb:
- Elektroinstallation erfolgen Bauseits durch einen Elekroinstallateur', 'Easybill 26-17922') returning id)
insert into public.easy_vorlage_zeile (vorlage_id, reihenfolge, typ, kategorie, artikel_id, bezeichnung, menge, einheit, preis, optional) values
((select id from v), 1, 'position', 'personal', null, 'Polier Wassergärten', 0, 'Std', 132, false),
((select id from v), 2, 'position', 'personal', (select id from artikel where artikelnummer_knecht='KNECHT_000005'), 'Gartenarbeiter', 0, 'Std', 82, false),
((select id from v), 3, 'position', 'personal', null, 'Fachplanung und Berechnung', 0, 'Std', 152, false),
((select id from v), 4, 'position', 'logistik', null, 'Lieferwagen, Servicefahrzeug,', 1, 'Std', 108, false),
((select id from v), 5, 'position', 'maschine', null, 'Kleinmaschinen und Geräte', 1, 'stk', 0, false),
((select id from v), 6, 'position', 'maschine', null, 'Baumschienen', 1, 'Budget', 0, false);

-- kurze Namen (Balken einzeilig)
update public.easy_vorlage set name = 'Budget kompakt' where quelle = 'Easybill 25-17288';
update public.easy_vorlage set name = 'Budget ausführlich' where quelle = 'Easybill 25-17266';
update public.easy_vorlage set name = 'Belagsreinigung bis 30 m²' where quelle = 'Easybill 26-17649';
update public.easy_vorlage set name = 'Teich Reinigung mit Fräsen' where quelle = 'Easybill 26-17876';
update public.easy_vorlage set name = 'Sanierung Divers' where quelle = 'Easybill 26-17922';
