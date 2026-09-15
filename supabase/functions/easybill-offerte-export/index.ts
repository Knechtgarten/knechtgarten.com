// ============================================================================
// Offertentool 2027 - Offerte als Angebot nach Easybill exportieren
// (schreibender Zugriff - bisher gab es nur die lesende Kundensuche, siehe
// easybill-kunden-suche).
//
// Liest den bereits beim letzten Speichern in Tool A berechneten
// kosten_snapshot der Offerte (Gruppen mit Label + Zeilen), baut daraus die
// Easybill-Dokument-Positionen (TEXT-Positionen als fette Zwischentitel pro
// Kategorie, PRODUCT-Positionen fuer die einzelnen Kosten-Zeilen) und legt
// per Easybill-API ein neues Angebot an (POST /documents) oder ueberschreibt
// ein bereits frueher exportiertes (PUT /documents/{id}).
//
// Layout-Feinschliff vom 2026-09-15 (Vorgabe: soll aehnlich formatiert sein
// wie bisherige, manuell erfasste Knechtgarten-Offerten in Easybill):
// - Offerten-Titel wird als "title" am Dokument selbst mitgegeben (erscheint
//   in Easybill neben der Angebotsnummer).
// - Kategorie-Zwischentitel (Personalaufwand usw.) werden mit <b>...</b> in
//   der description umschlossen, damit sie fett erscheinen - Easybills
//   eigener PDF-Renderer unterstuetzt das offenbar bei TEXT-Positionen (nicht
//   offiziell dokumentiert, aber so beobachtet). Falls das bei einem
//   naechsten Test stattdessen die Tags woertlich anzeigt, muss das wieder
//   raus.
// - Das neu angelegte/aktualisierte Angebot wird direkt danach automatisch
//   "fertiggestellt" (POST /documents/{id}/done, siehe holeEndgueltigeNummer
//   unten) - Easybill vergibt sonst laut API-Doku keine Angebotsnummer
//   (Feld "number" bleibt bei Entwuerfen leer). Nutzerentscheid vom
//   2026-09-15: lieber sofort mit echter Nummer, als dauerhaft nur die
//   interne Easybill-ID anzuzeigen.
//
// Voraussetzung: der Kunde der Offerte muss eine easybill_id haben (also aus
// Easybill importiert/verknuepft sein) - sonst gibt es keine gueltige
// customer_id fuer Easybill.
//
// Preise werden NETTO uebertragen, Easybill rechnet die MwSt selbst drauf
// (vat_percent pro Position) - siehe EASYBILL_MWST_SATZ unten: der
// kosten_snapshot traegt aktuell keinen MwSt-Satz pro Zeile, darum vorerst
// ein fester Satz fuer alle Positionen (8.1% Normalsatz, bislang der einzige
// bei Knechtgarten verwendete Satz).
//
// Aufruf vom Client: sb.functions.invoke('easybill-offerte-export',
//   { body: { offerte_id, modus: 'neu' | 'ueberschreiben' } })
// Antwort bei Erfolg: { document_id, document_number }
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const EASYBILL_BASE_URL = 'https://api.easybill.de/rest/v1';
const EASYBILL_MWST_SATZ = 8.1;

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

// Rundet auf Rappen und wandelt in die von Easybill erwartete Ganzzahl-
// Darstellung um (150 = CHF 1.50).
function chfZuRappen(chf: number): number {
  return Math.round((chf || 0) * 100);
}

// Easybill vergibt einem Dokument im Entwurfsstatus laut API-Doku keine
// Beleg-/Angebotsnummer (Feld "number" bleibt leer) - erst POST
// /documents/{id}/done "fertigstellt" das Dokument und loest die
// Nummernvergabe aus. Nutzerentscheid vom 2026-09-15: automatisch sofort
// fertigstellen (statt dauerhaft Entwurf), damit in Tool A sofort die echte
// Nummer (z.B. "26-18527") statt der internen Easybill-ID erscheint.
async function holeEndgueltigeNummer(documentId: number, auth: string): Promise<string | null> {
  const holeNummer = async () => {
    const res = await fetch(`${EASYBILL_BASE_URL}/documents/${documentId}`, { headers: { Authorization: auth } });
    if (!res.ok) return null;
    const ergebnis = await res.json().catch(() => null);
    return ergebnis?.number ?? null;
  };
  const bereitsVorhanden = await holeNummer();
  if (bereitsVorhanden) return bereitsVorhanden;
  try {
    // Laut easybill-API-Referenz (documentsIdDonePut) ist das ein PUT, nicht
    // POST - die Response enthaelt bereits das aktualisierte Dokument
    // inklusive der neu vergebenen Nummer, darum hier direkt daraus lesen
    // statt nochmal separat nachzufragen.
    const doneRes = await fetch(`${EASYBILL_BASE_URL}/documents/${documentId}/done`, { method: 'PUT', headers: { Authorization: auth } });
    if (doneRes.ok) {
      const doneErgebnis = await doneRes.json().catch(() => null);
      if (doneErgebnis?.number) return doneErgebnis.number;
    }
  } catch (_e) {
    // Fertigstellen fehlgeschlagen (z.B. bereits fertiggestellt, oder
    // Easybill laesst es fuer diesen Dokumenttyp/Status nicht zu) - kein
    // harter Fehler, wir zeigen dann weiterhin die interne ID als Fallback.
  }
  return await holeNummer();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { offerte_id, modus } = await req.json().catch(() => ({}));
    if (!offerte_id) return json({ error: 'offerte_id fehlt.' }, 400);
    if (!['neu', 'ueberschreiben', 'status'].includes(modus)) return json({ error: 'modus muss "neu", "ueberschreiben" oder "status" sein.' }, 400);

    const apiKey = Deno.env.get('EASYBILL_API_KEY');
    const email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) {
      return json({ error: 'Easybill ist noch nicht konfiguriert (EASYBILL_API_KEY/EASYBILL_EMAIL fehlen).' }, 500);
    }
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const sb = createClient(supabaseUrl, serviceRoleKey);

    const { data: offerte, error: offErr } = await sb
      .from('offerte')
      .select(`
        id, titel, offertnummer, kosten_snapshot, easybill_document_id, easybill_document_number,
        beschreibung_block, optionen_text_liste,
        kunde:kunde_id ( easybill_id, name )
      `)
      .eq('id', offerte_id)
      .single();
    if (offErr || !offerte) return json({ error: 'Offerte nicht gefunden.' }, 404);

    // "status": kein neuer Export, sondern nur nachfragen, ob Easybill dem
    // beim letzten Export noch nummernlosen Entwurf inzwischen eine
    // Angebotsnummer vergeben hat (das passiert bei Easybill nicht immer
    // sofort bei der Erstellung, siehe Beobachtung vom 2026-09-15: PDF aus
    // Easybill zeigte "26-18527", obwohl unser gespeichertes
    // easybill_document_number nach dem Export noch leer war). Wird von
    // Tool A automatisch im Hintergrund aufgerufen, wenn eine Offerte mit
    // Easybill-Verknuepfung aber ohne lokal bekannte Nummer geladen wird.
    if (modus === 'status') {
      if (!offerte.easybill_document_id) return json({ error: 'Für diese Offerte gibt es noch kein Easybill-Angebot.' }, 400);
      const neueNummer = await holeEndgueltigeNummer(offerte.easybill_document_id, auth);
      if (neueNummer && neueNummer !== offerte.easybill_document_number) {
        await sb.from('offerte').update({ easybill_document_number: neueNummer }).eq('id', offerte_id);
      }
      return json({ document_id: offerte.easybill_document_id, document_number: neueNummer });
    }

    const kunde = offerte.kunde as any;
    if (!kunde?.easybill_id) {
      return json({ error: 'Dieser Kunde ist nicht mit Easybill verknüpft (keine easybill_id). Bitte zuerst in Easybill erfassen oder hier mit einem bestehenden Easybill-Kunden verknüpfen.' }, 400);
    }

    if (modus === 'ueberschreiben' && !offerte.easybill_document_id) {
      return json({ error: 'Für diese Offerte gibt es noch kein Easybill-Angebot zum Überschreiben.' }, 400);
    }

    const snapshot = offerte.kosten_snapshot as { gruppen?: { label: string; zeilen: any[] }[] } | null;
    if (!snapshot?.gruppen?.length) {
      return json({ error: 'Diese Offerte hat noch keine berechnete Kostentabelle (bitte zuerst in Tool A einmal speichern).' }, 400);
    }

    // Positionen: pro Kategorie-Gruppe zuerst eine TEXT-Position (fetter
    // Zwischentitel), danach je eine PRODUCT-Position pro Kostenzeile -
    // geloeschte/ausgeblendete Zeilen (geloescht:true) werden uebersprungen,
    // genau wie in der Offerten-Ansicht selbst.
    const items: any[] = [];
    if (offerte.beschreibung_block?.trim()) {
      items.push({ type: 'TEXT', description: offerte.beschreibung_block.trim() });
    }
    for (const gruppe of snapshot.gruppen) {
      const zeilen = (gruppe.zeilen || []).filter((z: any) => !z.geloescht);
      if (!zeilen.length) continue;
      // Fett dargestellt, wie es Easybills eigener PDF-Renderer bei <b>...</b>
      // in der description auch fuer manuell erfasste Zwischentitel tut.
      items.push({ type: 'TEXT', description: `<b>${gruppe.label}</b>` });
      for (const z of zeilen) {
        items.push({
          type: 'PRODUCT',
          description: z.bezeichnung,
          quantity: z.menge,
          unit: z.einheit || undefined,
          single_price_net: chfZuRappen(z.preis),
          vat_percent: EASYBILL_MWST_SATZ,
        });
      }
    }
    if (offerte.optionen_text_liste?.trim()) {
      items.push({ type: 'TEXT', description: offerte.optionen_text_liste.trim() });
    }

    const payload = {
      type: 'OFFER',
      title: offerte.titel || undefined,
      customer_id: kunde.easybill_id,
      currency: 'CHF',
      items,
    };

    const istUeberschreiben = modus === 'ueberschreiben';
    const url = istUeberschreiben ? `${EASYBILL_BASE_URL}/documents/${offerte.easybill_document_id}` : `${EASYBILL_BASE_URL}/documents`;
    const method = istUeberschreiben ? 'PUT' : 'POST';

    const res = await fetch(url, {
      method,
      headers: { Authorization: auth, 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const ergebnis = await res.json().catch(() => null);
    if (!res.ok) {
      return json({ error: `Easybill hat den Export abgelehnt: ${JSON.stringify(ergebnis)}` }, res.status);
    }

    const easybillNummer = await holeEndgueltigeNummer(ergebnis.id, auth);

    const { error: updateErr } = await sb.from('offerte').update({
      easybill_document_id: ergebnis.id,
      easybill_document_number: easybillNummer,
      easybill_exported_at: new Date().toISOString(),
    }).eq('id', offerte_id);
    if (updateErr) return json({ error: friendlyDbError(updateErr) }, 500);

    return json({ document_id: ergebnis.id, document_number: easybillNummer });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function friendlyDbError(e: unknown): string {
  return `Angebot wurde in Easybill angelegt, aber die Rückspeicherung ins Offertentool ist fehlgeschlagen: ${String(e)}`;
}
