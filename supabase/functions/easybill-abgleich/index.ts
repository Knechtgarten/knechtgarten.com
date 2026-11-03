// ============================================================================
// Easybill-Abgleich (nur lesend, in Easybill wird nichts geschrieben).
// Holt den Kundenstamm in unsere Tabelle kunde (Zuordnung über easybill_id,
// nur echte Kunden mit Kundennummer, keine Lieferanten) sowie die
// Auftragsbestätigungen (ORDER) und die Angebote (OFFER), auf die sie
// verweisen, in easybill_dokument.
//
// Aufruf:
//   { modus: 'nacht' }  – vom nächtlichen Cron (Header x-abgleich-token)
//   { modus: 'alles' }  – Knopf «Jetzt alles holen» (angemeldete Person)
//   { modus: 'kunde', kunde_id } – ein Kunde inkl. älterer Dokumente
// 'nacht'/'alles': Kunden komplett, ABs der letzten zwei Jahre.
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-abgleich-token',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const EB = 'https://api.easybill.de/rest/v1';
const LAND: Record<string, string> = { CH: 'Schweiz', DE: 'Deutschland', AT: 'Österreich' };

const ohneHtml = (s: string | null) => s
  ? s.replace(/<br\s*\/?>/gi, '\n').replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&auml;/g, 'ä').replace(/&ouml;/g, 'ö').replace(/&uuml;/g, 'ü').replace(/&Auml;/g, 'Ä').replace(/&Ouml;/g, 'Ö').replace(/&Uuml;/g, 'Ü')
      .replace(/&szlig;/g, 'ss').replace(/&#?\w+;/g, ' ').replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim()
  : null;
const datumMinus = (jahre: number) => { const d = new Date(); d.setFullYear(d.getFullYear() - jahre); return d.toISOString().slice(0, 10); };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const url = Deno.env.get('SUPABASE_URL')!;
  const db = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  let logId: number | null = null;
  try {
    const body = await req.json().catch(() => ({}));
    const modus = body.modus || 'alles';

    // Berechtigung: Cron über geheimen Header, sonst angemeldete, freigeschaltete Person
    let benutzerId: string | null = null;
    const token = Deno.env.get('EASYBILL_ABGLEICH_TOKEN');
    const cron = !!token && req.headers.get('x-abgleich-token') === token;
    if (!cron) {
      const nutzer = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
      const { data: { user } } = await nutzer.auth.getUser();
      if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
      const { data: b } = await db.from('benutzer').select('aktiv,rolle').eq('id', user.id).maybeSingle();
      if (!b || !b.aktiv || !b.rolle) return json({ error: 'Kein Zugriff.' }, 403);
      benutzerId = user.id;
    } else if (modus !== 'nacht') return json({ error: 'Cron darf nur den Nachtlauf starten.' }, 403);

    const apiKey = Deno.env.get('EASYBILL_API_KEY'), email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) return json({ error: 'Easybill ist nicht konfiguriert.' }, 500);
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);
    const eb = async (pfad: string) => {
      for (let versuch = 0; versuch < 3; versuch++) {
        const r = await fetch(EB + pfad, { headers: { Authorization: auth } });
        if (r.status === 429) { await new Promise((ok) => setTimeout(ok, 4000)); continue; } // Rate-Limit: kurz warten
        if (!r.ok) throw new Error(`Easybill ${r.status} bei ${pfad.split('?')[0]}`);
        return await r.json();
      }
      throw new Error('Easybill: zu viele Anfragen, bitte später nochmals.');
    };
    const alleSeiten = async (pfad: string) => {
      const items: any[] = []; let seite = 1, seiten = 1;
      do { const r = await eb(`${pfad}${pfad.includes('?') ? '&' : '?'}limit=1000&page=${seite}`); items.push(...(r.items || [])); seiten = r.pages || 1; seite++; } while (seite <= seiten);
      return items;
    };

    let kundeId: string | null = null, kundeEb: number | null = null;
    if (modus === 'kunde') {
      kundeId = body.kunde_id;
      const { data: k } = await db.from('kunde').select('easybill_id').eq('id', kundeId).maybeSingle();
      if (!k || !k.easybill_id) return json({ error: 'Dieser Kunde ist nicht mit Easybill verknüpft.' }, 400);
      kundeEb = k.easybill_id;
    }
    const { data: log } = await db.from('easybill_abgleich').insert({ modus, kunde_id: kundeId, ausgeloest_von: benutzerId }).select('id').single();
    logId = log?.id ?? null;

    // 1) Kunden -----------------------------------------------------------------------------
    const ebKunden = kundeEb ? [await eb(`/customers/${kundeEb}`)] : await alleSeiten('/customers');
    const zeilen = ebKunden.filter((k: any) => k && k.number).map((k: any) => ({
      easybill_id: k.id,
      name: k.company_name || [k.first_name, k.last_name].filter(Boolean).join(' ') || k.display_name || null,
      firma: k.company_name || null,
      vorname: k.first_name || null,
      nachname: k.last_name || null,
      kundennummer: k.number || null,
      strasse: k.street || null,
      plz: k.zip_code || null,
      ort: k.city || null,
      land: LAND[k.country] || k.country || null,
      kontaktdaten: { telefon1: k.phone_1 || null, telefon2: k.phone_2 || null, fax: k.fax || null, mobil: k.mobile || null, emails: k.emails || [] },
    }));
    for (let i = 0; i < zeilen.length; i += 500) {
      const { error } = await db.from('kunde').upsert(zeilen.slice(i, i + 500), { onConflict: 'easybill_id' });
      if (error) throw new Error('Kunden speichern: ' + error.message);
    }
    // Zuordnung easybill_id -> kunde.id (für die Dokumente)
    const kundeVon = new Map<number, string>();
    for (let von = 0; ; von += 1000) {
      const { data, error } = await db.from('kunde').select('id,easybill_id').not('easybill_id', 'is', null).range(von, von + 999);
      if (error) throw new Error(error.message);
      (data || []).forEach((k: any) => kundeVon.set(Number(k.easybill_id), k.id));
      if (!data || data.length < 1000) break;
    }

    // 2) Auftragsbestätigungen + verwiesene Angebote ----------------------------------------------
    const filter = kundeEb ? `&customer_id=${kundeEb}` : `&document_date=${datumMinus(2)},${datumMinus(-1)}`;
    const abs = (await alleSeiten(`/documents?type=ORDER&is_draft=0${filter}`)).filter((d: any) => !d.cancel_id);
    const angebotNr = (d: any) => {
      const s = new Set<string>();
      (d.items || []).forEach((p: any) => {
        if (p.number && /^\d{2}-\d+$/.test(p.number)) s.add(p.number);
        for (const m of String(p.description || '').matchAll(/Angebot:?\s*(\d{2}-\d{3,})/g)) s.add(m[1]);
      });
      return [...s];
    };
    const nummern = [...new Set(abs.flatMap(angebotNr))];
    const angebote: any[] = [];
    for (let i = 0; i < nummern.length; i += 25) angebote.push(...await alleSeiten(`/documents?type=OFFER&number=${encodeURIComponent(nummern.slice(i, i + 25).join(','))}`));

    const dok = (d: any, typ: string) => ({
      easybill_id: d.id, typ, nummer: d.number || null, titel: d.title || null, datum: d.document_date || null,
      kunde_easybill_id: d.customer_id || null, kunde_id: kundeVon.get(Number(d.customer_id)) || null,
      betrag_netto: d.amount_net != null ? d.amount_net / 100 : null,
      text_prefix: ohneHtml(d.text_prefix), text: ohneHtml(d.text),
      positionen: (d.items || []).map((p: any) => ({
        pos: p.position, typ: p.type, text: p.description || '', menge: p.quantity ?? null, einheit: p.unit || null,
        nummer: p.number || null, betrag_netto: p.total_price_net != null ? p.total_price_net / 100 : null,
      })),
      angebot_nummern: typ === 'ORDER' ? angebotNr(d) : [],
      geaendert_easybill: d.edited_at ? d.edited_at.replace(' ', 'T') + '+01:00' : null,
      abgeglichen_am: new Date().toISOString(),
    });
    const doks = [...abs.map((d: any) => dok(d, 'ORDER')), ...angebote.filter((d: any) => !d.is_draft).map((d: any) => dok(d, 'OFFER'))];
    for (let i = 0; i < doks.length; i += 200) {
      const { error } = await db.from('easybill_dokument').upsert(doks.slice(i, i + 200), { onConflict: 'easybill_id' });
      if (error) throw new Error('Dokumente speichern: ' + error.message);
    }

    // 3) Angebote ↔ unsere Offerten verbinden, Offerten in einer AB = bestätigt (zugesagt)
    const { data: vk, error: vkFehler } = await db.rpc('easybill_verknuepfen');
    if (vkFehler) throw new Error('Offerten verknüpfen: ' + vkFehler.message);

    const ergebnis = { kunden: zeilen.length, auftragsbestaetigungen: abs.length, angebote: angebote.length, ...(vk || {}) };
    if (logId) await db.from('easybill_abgleich').update({ beendet: new Date().toISOString(), kunden: zeilen.length, dokumente: doks.length }).eq('id', logId);
    return json(ergebnis);
  } catch (e) {
    const msg = String(e instanceof Error ? e.message : e);
    if (logId) await db.from('easybill_abgleich').update({ beendet: new Date().toISOString(), fehler: msg }).eq('id', logId);
    return json({ error: msg }, 500);
  }
});
