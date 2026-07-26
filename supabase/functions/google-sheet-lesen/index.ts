// ============================================================================
// Offertentool 2027 - Google-Sheet-Lesen (read-only)
//
// Liest ein oeffentlich freigegebenes Google Sheet ("Jeder mit dem Link kann
// ansehen") als CSV ein - laeuft serverseitig, damit kein CORS-Problem
// entsteht und kein Google-Login noetig ist. Schreibt NICHTS zurueck, reine
// Vorschau/Lese-Funktion fuer den Lieferanten-Datenabgleich.
//
// Aufruf vom Client: sb.functions.invoke('google-sheet-lesen', { body: { link: 'https://docs.google.com/spreadsheets/d/...' } })
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

// Einfacher CSV-Parser (unterstuetzt in Anfuehrungszeichen stehende Felder
// mit Kommas/Zeilenumbruechen darin, wie sie Google Sheets exportiert).
function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let feld = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') { feld += '"'; i++; }
        else inQuotes = false;
      } else {
        feld += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ',') {
      row.push(feld); feld = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(feld); feld = '';
      rows.push(row); row = [];
    } else {
      feld += ch;
    }
  }
  if (feld !== '' || row.length) { row.push(feld); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { link } = await req.json().catch(() => ({ link: '' }));
    const idMatch = String(link || '').match(/\/spreadsheets\/d\/([a-zA-Z0-9-_]+)/);
    if (!idMatch) {
      return json({ error: 'Kein gueltiger Google-Sheet-Link erkannt.' }, 400);
    }
    const gidMatch = String(link).match(/gid=(\d+)/);
    const sheetId = idMatch[1];
    const gid = gidMatch ? gidMatch[1] : '0';
    const csvUrl = `https://docs.google.com/spreadsheets/d/${sheetId}/export?format=csv&gid=${gid}`;

    const res = await fetch(csvUrl);
    if (res.status === 401 || res.status === 403) {
      return json({ error: 'Das Sheet ist nicht oeffentlich freigegeben - bitte auf "Jeder mit dem Link kann ansehen" stellen.' }, 400);
    }
    if (!res.ok) {
      return json({ error: `Sheet konnte nicht gelesen werden (Status ${res.status}).` }, 400);
    }
    const text = await res.text();
    const rows = parseCsv(text);
    if (!rows.length) {
      return json({ error: 'Das Sheet enthaelt keine Daten.' }, 400);
    }
    const [headers, ...datenzeilen] = rows;

    // Echter Dateiname (wie in Google Drive) - aus der leichten "htmlview"-
    // Vorschauseite ausgelesen, nur damit der Mitarbeitende im Zuordnungs-
    // Fenster sieht, welche Datei geladen wurde. Rein informativ - schlaegt
    // die Titel-Suche fehl, wird einfach kein Titel zurueckgegeben.
    let titel: string | null = null;
    try {
      const previewRes = await fetch(`https://docs.google.com/spreadsheets/d/${sheetId}/htmlview`);
      if (previewRes.ok) {
        const previewHtml = await previewRes.text();
        const titleMatch = previewHtml.match(/<title>(.*?)<\/title>/i);
        if (titleMatch) {
          titel = titleMatch[1]
            .replace(/\s*-\s*Google (Tabellen|Sheets|Spreadsheets)\s*$/i, '')
            .trim() || null;
        }
      }
    } catch (_e) {
      // Titel ist rein informativ - ein Fehlschlag hier darf den Abgleich nicht blockieren.
    }

    return json({ headers, rows: datenzeilen, titel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
