-- Gartenbeleuchtung › Netzteil › Option «Dali-Steuerung»: 4-Kanal Handsender ergänzen
-- (Kopie der Handsender-Zeile von «Ein/Aus Mono», nur andere Option/Reihenfolge)
insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz,
  zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, teilschritt_id, mindestmenge, verschnitt_prozent,
  staffelgruppe_id, zonengruppe_id, sonderposition_typ_id, tagesleistung_menge, reihenfolge, ist_eigene_offertenposition,
  zuschlag_prozent, menge_formel_modus, menge_formel_text, menge_formel_baukasten_ausdruck, auswahlgruppe_id, mengenoption_ausgenommen)
select '275c3227-89c9-465a-82f0-920cf5369f5e', kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz,
  zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, null, mindestmenge, verschnitt_prozent,
  staffelgruppe_id, zonengruppe_id, sonderposition_typ_id, tagesleistung_menge, 4, ist_eigene_offertenposition,
  zuschlag_prozent, menge_formel_modus, menge_formel_text, menge_formel_baukasten_ausdruck, auswahlgruppe_id, mengenoption_ausgenommen
from ressourcenzeile
where id = '96db862b-0dc3-467e-afa5-228e89fefd40'
  and not exists (select 1 from ressourcenzeile where option_id = '275c3227-89c9-465a-82f0-920cf5369f5e' and artikel_id = '19332ebc-708d-4ceb-b270-dd668410ed7a');
