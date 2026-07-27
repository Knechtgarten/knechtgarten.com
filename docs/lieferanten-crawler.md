# Lieferanten-Shop-Crawler - Übersicht & Troubleshooting

Diese Datei dokumentiert die Shop-Crawling-Funktionalität im Offertentool
(`app/lieferant-abgleich-live-v1.html` + `supabase/functions/shop-crawling-*-lesen`).
Sie ist als Einstiegspunkt gedacht, falls ein Abgleich bei einem Lieferanten
plötzlich nicht mehr funktioniert (z.B. weil der Shop ein Redesign bekommen
hat) - egal ob die nächste Session mit Claude Code die aktuelle ist oder eine
ganz neue.

## Grundprinzip

Für jeden unterstützten Shop-Software-Typ gibt es eine eigene Supabase Edge
Function `supabase/functions/shop-crawling-<typ>-lesen/index.ts`. Das
Frontend ruft automatisch die passende Funktion auf, basierend auf dem
Dropdown-Wert "Shop-Software" beim Lieferanten:

```js
const shopSoftware = (LIEF.da.sync_verbindung || {}).shop_software || 'gambio';
sb.functions.invoke(`shop-crawling-${shopSoftware}-lesen`, { body: { lieferant_id, url } });
```

Neue Shop-Software → neue Edge Function + neuer `<option>` im Dropdown in
`app/lieferant-abgleich-live-v1.html`. Neue Theme-/Markup-Variante *derselben*
Software (z.B. Magento mit anderem Wishlist-Modul) → einfach ein neuer Zweig
*innerhalb* der bestehenden Funktion, per Laufzeit-Erkennung (siehe Magento
unten) - kein neuer Dropdown-Eintrag nötig.

## Warum Crawling statt API

Bewusster Entscheid (Session 2026-07-27): Der Nutzer synchronisiert Preise
nur 3-4x pro Jahr pro Lieferant. Der Aufwand, mit jedem Lieferanten eine
API-Anbindung auszuhandeln, lohnt sich bei dieser Frequenz nicht - eine
manuell kopierte Browser-Session reicht, weil sie ohnehin vor jedem Abgleich
neu geholt wird. Das grössere Risiko ist ein Shop-Redesign (bricht die
HTML-Regex), aber das ist typischerweise ein kleiner, schneller Fix (siehe
Troubleshooting unten), kein Neubau.

## Session-Workflow (gilt für alle Shops)

Da jeder Shop einen echten Login braucht und automatisiertes Einloggen an
CAPTCHA/Cloudflare scheitert, läuft die Authentifizierung manuell:

1. Nutzer loggt sich im Browser normal beim Lieferanten-Shop ein.
2. DevTools öffnen (F12) → Tab **Network** → Filter auf **All** (nicht
   Fetch/XHR - der Haupt-Seitenaufruf läuft nur unter "All").
3. Seite neu laden (F5).
4. Eine beliebige Zeile suchen, die zur **eigenen Domain des Shops** gehört
   (nicht zu Drittanbietern wie Google Analytics/Tag Manager - die tragen
   keinen Session-Cookie).
5. Rechtsklick → Copy → **Copy as cURL (bash)**.
6. Einfügen im Feld "Session (aus Browser kopiert)" beim Lieferanten in
   `lieferant-abgleich-live-v1.html`.

Die Extraktion des reinen Cookie-Werts aus dem eingefügten cURL-Text passiert
in `extrahiereCookieAusCurl()` (gleiche Datei). Der Cookie wird per Supabase
Vault gespeichert und über die RPC `lese_shop_session(p_lieferant_id)`
serverseitig (admin-only) wieder ausgelesen.

## Unterstützte Shop-Plattformen

| Dropdown-Wert | Edge Function | Beispiel-Lieferanten | Besonderheit |
|---|---|---|---|
| `gambio` | `shop-crawling-gambio-lesen` | Koi-Breeder | Merkliste hat Preise |
| `magento` | `shop-crawling-magento-lesen` | Aqua-Tech (Amasty-Wishlist), Aqua Solar (natives Hyva-Wishlist) | 2 Markup-Varianten, per `erkenneMerklistenTyp()` automatisch erkannt |
| `hybris` | `shop-crawling-hybris-lesen` | HGC | Daten stecken als JSON in `window.initialData['favorites/data']`, kein Regex-Parsing nötig |
| `dabag` | `shop-crawling-dabag-lesen` | B-Team Bern, IMMER AG | Merkliste hat KEINE Preise - Crawler liest den **Warenkorb**, nicht die Merkliste (siehe unten) |

### Dabag-Plattform im Detail (B-Team Bern, IMMER AG)

Erkennbar an: CSS-Klasse `dabagTooltipLocal`, Bilder-Domain
`bilder.dabag.ch`, URL-Pfade `/pagesshop/` und `/pagespartner/`.

**Wichtigste Eigenheit:** die Merkliste/Favoriten-Seite zeigt keine Preise -
nur Artikelnummer, Bezeichnung, EAN, Menge. Preise (Richtpreis, Rabatt,
Netto-Preis, Total) erscheinen erst im **Firmenwarenkorb**
(`?srv=basket&companyYN=1` bzw. ohne den zweiten Parameter, je nach Shop).
Der Nutzer legt die zu synchronisierenden Artikel darum selbst in den
Warenkorb statt in eine Merkliste, und die hinterlegte URL zeigt auf den
Warenkorb, nicht auf die Merkliste.

Anker pro Artikel: `<tr id="bsi-NNNNNNNN" class="bsi-row ...">`. Die
zugehörige "Kommission"-Zusatzzeile heisst `bsi-kommission-NNNNNNNN`
(Buchstaben statt Ziffern direkt nach `bsi-`), wird also nicht fälschlich
als eigener Artikel erkannt.

**Zwei echte Markup-Unterschiede zwischen B-Team und IMMER AG, obwohl
gleiche Plattform** (beide schon gefixt, Stand 2026-07-27):
- Artikelnummer steht bei B-Team in `<b>...</b>`, bei IMMER AG ohne
  `<b>`-Umschlag direkt im Link. Die Regex deckt seither beide Fälle ab.
- Der Preis (`data-title="Netto-Preis"`) steht bei IMMER AG mit einem
  eingebetteten `<span>CHF</span>` vor der Zahl, bei B-Team als reiner Text.
  Die Regex fängt seither die ganze Zellen-Innenhtml ein, entfernt Tags und
  "CHF", und parst erst danach die Zahl - robust für beide Varianten.

Das zeigt gut, wieso "gleiche Plattform" nicht "identisches Markup"
garantiert - beim nächsten neuen Dabag-Lieferanten lohnt sich ein kurzer
Testlauf, auch wenn keine neue Funktion nötig ist.

## Troubleshooting: "0 Artikel gefunden"

Seit Session 2026-07-27 zeigt die Abgleich-Seite bei 0 gefundenen Artikeln
automatisch einen Kasten "Debug-Info (0 Artikel gefunden)" mit einem
"Debug-Info kopieren"-Knopf (siehe `zeigeDebugInfo()` in
`app/lieferant-abgleich-live-v1.html`). Der Nutzer muss dafür nicht mehr in
die Browser-DevTools - einfach den Knopf klicken und das Ergebnis hier im
Chat einfügen.

Die Debug-Daten kommen aus der jeweiligen Edge Function und enthalten
typischerweise:
- `htmlLaenge`: Länge der abgerufenen Seite (sehr kurz → Session abgelaufen
  oder falsche URL).
- Ein Flag, ob das erwartete Anker-Muster überhaupt gefunden wurde (z.B.
  `hatBsiRow` bei Dabag) → wenn `false`, meist Session abgelaufen oder
  falsche Seite (Login-Seite statt Warenkorb/Merkliste).
- Ein HTML-Ausschnitt rund um das erste gefundene Item → zeigt, ob nur ein
  einzelnes Feld (Preis, Artikelnummer, Foto) nicht passt, während der Rest
  funktioniert.

**Vorgehen bei einem Fehlerbericht:**
1. Debug-Info anschauen: kommt überhaupt HTML mit sinnvoller Länge zurück?
   Falls nein oder sehr kurz → Session ist wahrscheinlich abgelaufen, neu
   einloggen und "Copy as cURL" wiederholen lassen.
2. Falls HTML da ist, aber das Anker-Muster nicht gefunden wird → Nutzer
   bitten, im Shop selbst per Seitenquelltext (Strg+U) oder DevTools den
   entsprechenden Ausschnitt zu suchen und zu schicken - genau wie bei der
   Ersteinrichtung von B-Team/IMMER AG in dieser Session.
3. Kleine Markup-Abweichung in der bestehenden Regex nachziehen (siehe
   Beispiel oben bei IMMER AG), balance-checken (siehe unten), committen,
   pushen, aktualisierten Funktionscode als kompletten Codeblock im Chat
   zeigen (siehe Regel unten), Nutzer deployt über Supabase Dashboard neu.

## Wichtige Standing Rules für Änderungen an diesen Funktionen

- **Balance-Check vor jedem Commit**: da lokal kein Node/TypeScript-Compiler
  zur Verfügung steht, vor jedem Commit an einer `.ts`- oder `.html`-Datei
  Klammern/Klammerpaare zählen (PowerShell:
  `[regex]::Matches($c,'\{').Count` etc. für `{`/`}` und `(`/`)`) und
  vergleichen.
- **Sofort committen + pushen** nach jeder fertigen, geprüften Änderung.
- **Kompletter Code im Chat**: Edge-Function-Code (wie SQL-Migrationen) immer
  als vollständigen, kopierbaren Codeblock im Chat zeigen - nie nur einen
  Link zum Supabase Dashboard. Der Nutzer muss den Code von Hand ins
  Dashboard einfügen und selbst deployen.
- **Foto-Spiegelung**: alle Crawler laden Artikel-Fotos serverseitig herunter
  und laden sie in den eigenen Storage-Bucket `artikel-fotos` hoch (in
  Gruppen von 8 parallel), statt nur die fremde URL zu speichern - bleibt so
  erhalten, falls der Lieferant sein Bild später löscht/verschiebt.
