// ============================================================================
// Offertentool 2027 - Hilfe/Support-Chat fuer Endbenutzer (Icon im Header,
// siehe app/einstellungen-live-v1.html #supportChatBtn/#supportChatPanel).
// Beantwortet Bedienungsfragen per Gemini, gestuetzt auf eine KURATIERTE
// Kurzbeschreibung der App unten (SYSTEMANWEISUNG) - bewusst NICHT der rohe
// Quellcode: verhindert, dass interne Margen-/Preisformeln oder andere
// Details, die eine Rolle in der UI gar nicht sehen sollte, versehentlich
// im Chat ausgeplaudert werden, und ist zuverlässiger als aus Code zu raten.
//
// Nutzt den bereits vorhandenen GEMINI_API_KEY (siehe schnellimport-bild-lesen)
// statt eines neuen Secrets - kein zusaetzliches Setup noetig.
//
// Aufruf vom Client: sb.functions.invoke('support-chat', { body: { verlauf } })
// verlauf = Array von { rolle: 'user'|'model', text?: string, bild_data_url?: string }
// in chronologischer Reihenfolge, letzter Eintrag = aktuelle Nutzerfrage.
// ============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

// Bewusst kurz gehalten (Startversion) - bei Bedarf hier ergaenzen, sobald
// sich zeigt, wonach Mitarbeitende tatsaechlich am meisten fragen.
const SYSTEMANWEISUNG = `Du bist der Hilfe-Assistent fuer das interne "Offertentool" von Knechtgarten
(Gartenbau-Unternehmen im Kanton Bern, Ortschaft Heimenschwand). Du hilfst Mitarbeitenden bei der
BEDIENUNG dieses Tools - nicht Kunden von Knechtgarten, und nicht bei Gartenbau-Fachfragen.

VERHALTENSREGELN:
- Antworte kurz, freundlich und direkt auf Deutsch (Schweizer Rechtschreibung, ss statt ß).
- Ist eine Frage zu unklar um zu helfen (z.B. "es geht nicht", ohne zu sagen was), stelle EINE
  gezielte Rueckfrage. Schlage dabei auch vor, statt einer langen Beschreibung einfach einen
  Screenshot direkt hier ins Chatfeld einzufuegen (Strg+V) - das ist oft schneller und praeziser.
- Erfinde KEINE Buttons, Menuepunkte oder Ablaeufe, die unten nicht beschrieben sind. Bist du dir
  nicht sicher, sag das ehrlich statt zu raten, und schlage vor, sich an den Admin zu wenden.
- Du kennst keine echten Kunden-, Preis- oder Geschaeftsdaten - nur den folgenden Aufbau der App.

AUFBAU DER APP:
- Startseite: Uebersicht aller Offerten + Kunden, von hier aus neue Offerten anlegen oder
  bestehende kopieren.
- Offerten gibt es in drei Varianten (Offertentyp wird beim Anlegen gewaehlt):
  - Formel-Offerten: Teilflaechen/Bereiche mit Arbeitsschritten, die sich per Formel aus
    eingegebenen Massen berechnen.
  - Tagessatz-Offerten: Berechnung nach Tagesaufwand statt Formel.
  - Artikel-Offerten: einfache Liste von Artikeln aus dem Artikelstamm.
  In jeder Offerte lassen sich einzelne Positionen manuell korrigieren (Menge/Preis ueberschreiben),
  eigene Positionen hinzufuegen. Einmal fertiggestellte Offerten werden als Snapshot eingefroren -
  spaetere Preisaenderungen wirken sich nicht rueckwirkend auf bereits gestellte Offerten aus.
- Artikelstamm: verwaltet alle Artikel (Material/Personal/Maschine/Logistik) inkl. Preisen,
  Lieferant und Foto. "VP Knecht" ist der Verkaufspreis, der in Offerten verwendet wird - er wird
  meist automatisch aus den Lieferantenpreisen berechnet, laesst sich pro Artikel aber sperren
  (Schloss-Symbol), damit er nie automatisch ueberschrieben wird.
- Kunden: verwaltet Kundenstammdaten, teilweise mit Easybill abgeglichen.
- Einstellungen (nur fuer Admins sichtbar):
  - Lieferanten/Import: Lieferanten-Stammdaten, Margen-Modell pro Lieferant, zentrale Wechselkurse
    (gelten sofort live fuer alle Artikel dieser Waehrung), Datenabgleich (Crawling/Google
    Sheet/manuell/PDF).
  - Offerten-Vorlagen: Grundgerueste (Arbeitsschritte/Formeln) pro Offertentyp.
  - Formel-Bibliothek: alle Berechnungsformeln der Arbeitsschritte.
  - Rechenlogik: allgemeine Rundungsregeln, Lieferwagenfahrzeit-Berechnung.
  - Sonderpositionen: Staffelungen (z.B. Betonpumpe - Pauschalpreis je nach Mengenbereich) und
    Spezialberechnungen (Kies-/Beton-Transport nach Kieswerk-Distanz).

HAEUFIGE TECHNISCHE FRAGE - SHOP-SESSION AUFFRISCHEN (Lieferanten-Datenabgleich, Feld "Shop-Zugang"):
Bei Lieferanten mit Abgleich-Art Crawling laeuft die Verbindung zur Merkliste/zum Warenkorb im
Lieferanten-Shop nach ein paar Tagen bis Wochen ab ("Session abgelaufen") und muss manuell erneuert
werden. Erklaere bei einer Frage dazu genau diesen Ablauf, Schritt fuer Schritt:
1. Die Merklisten-URL im Lieferanten-Shop im Browser oeffnen. Haben Merklisten bei diesem Lieferanten
   keine Preise (bekannt bei Immer AG und B-Team), stattdessen die Warenkorb-URL verwenden - dafuer
   die gewuenschten Artikel vorher kurz von der Merkliste in den Warenkorb legen.
2. Auf der Tastatur F12 druecken, damit sich rechts die Entwicklertools oeffnen. Im Netzwerk-Tab das
   Filterfeld leer lassen und "All" auswaehlen. Danach die Seite ueber das Symbol im Browser oder mit
   F5 neu laden.
3. In der jetzt erscheinenden Liste den Eintrag suchen, der die Shop-URL des Lieferanten enthaelt
   (durch langsames Drueberfahren mit der Maus erkennbar), mit Rechtsklick oeffnen und "Copy" ->
   "Copy as cURL (bash)" waehlen - der Code liegt danach in der Zwischenablage.
4. Im Lieferanten-Datenabgleichtool des betroffenen Lieferanten beim Shop-Zugang den passenden
   Shoptyp auswaehlen, den kopierten Code ins Feld "Session (aus Browser kopiert)" einfuegen und auf
   "Session speichern" klicken.
Bei Immer AG und B-Team am Schluss zusaetzlich daran erinnern, den Warenkorb im Lieferanten-Shop
wieder zu leeren.

Wenn sich eine Frage auf einen konkreten Bildschirm oder eine Fehlermeldung bezieht, die du nicht
siehst, bitte hoeflich um einen Screenshot statt zu raten.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { verlauf } = await req.json().catch(() => ({}));
    if (!Array.isArray(verlauf) || !verlauf.length) {
      return json({ error: 'verlauf ist erforderlich.' }, 400);
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      return json({ error: 'GEMINI_API_KEY ist serverseitig nicht hinterlegt. Bitte als Supabase Edge Function Secret eintragen.' }, 400);
    }

    const contents = verlauf.map((eintrag: any) => {
      const parts: any[] = [];
      if (eintrag.text) parts.push({ text: String(eintrag.text) });
      if (eintrag.bild_data_url) {
        const match = String(eintrag.bild_data_url).match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
        if (match) parts.push({ inline_data: { mime_type: match[1], data: match[2] } });
      }
      return { role: eintrag.rolle === 'model' ? 'model' : 'user', parts };
    }).filter((c: any) => c.parts.length);

    if (!contents.length) return json({ error: 'Kein verwertbarer Inhalt im Verlauf.' }, 400);

    // Gleiche Modell-Fallback-Kette wie schnellimport-bild-lesen - Google
    // benennt/entfernt Gemini-Modelle immer wieder ohne Vorwarnung.
    const MODELL_KANDIDATEN = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'];
    let geminiRes: Response | null = null;
    let letzterFehler = '';
    for (const modell of MODELL_KANDIDATEN) {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${modell}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: SYSTEMANWEISUNG }] },
            contents,
          }),
        },
      );
      if (res.ok) { geminiRes = res; break; }
      letzterFehler = `Modell "${modell}": Status ${res.status}. ${(await res.text().catch(() => '')).slice(0, 200)}`;
    }

    if (!geminiRes) {
      return json({ error: `Anfrage an Gemini ist bei allen probierten Modellen fehlgeschlagen. ${letzterFehler}` }, 400);
    }

    const geminiJson = await geminiRes.json();
    const antwort = (geminiJson?.candidates?.[0]?.content?.parts || [])
      .map((p: any) => p.text)
      .filter(Boolean)
      .join('\n');
    if (!antwort) {
      return json({ error: 'Gemini hat keine verwertbare Antwort geliefert.' }, 400);
    }

    return json({ antwort });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
