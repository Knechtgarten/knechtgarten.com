// Zoll (BAZG → PEAX): Veranlagungsverfügungen sammeln, die Browser-Erweiterung hängt sie in PEAX an die Spediteur-Rechnung.
// Aktionen:
//   { aktion: 'abruf' }  – pg_cron alle 5 Min: Mails an zoll@knechtgarten.ch (Alias am Konto mail@) über Gmail holen,
//                          PDF-Anhänge in Storage «zoll» ablegen, Zollanmeldungsnummer (z. B. 26CHEI…) und Art (MWST/Zoll) erkennen.
//                          Angenommen: Absender @knechtgarten.ch (weitergeleitet) oder *.admin.ch (BAZG/e-dec-web).
//   { aktion: 'offen', googleAccessToken }      – Erweiterung: offene MWST-Verfügungen holen (mit Riegel 3 Min gegen Doppelarbeit)
//   { aktion: 'ergebnis', googleAccessToken, id, ergebnis, peax_doc_id?, peax_titel? } – Erweiterung meldet das Resultat
// Gibt beim Abruf nur Anzahlen zurück.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';
const KONTO = 'mail@knechtgarten.ch', ADRESSE = 'zoll@knechtgarten.ch';
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });
const b64 = (s: string) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const textAus = (s: string) => new TextDecoder().decode(b64(s));
const ZANR = /\b\d{2}CH[A-Z]{2}\d{12,14}\b/g;
const teile = (p: any, out: any[] = []) => { out.push(p); (p.parts || []).forEach((c: any) => teile(c, out)); return out; };

// Text aus einem PDF grob lesen: rohe Bytes + alle Flate-Streams entpackt (für Nummer und Art, kein sauberes Layout nötig)
async function pdfText(u8: Uint8Array): Promise<string> {
  const raw = new TextDecoder('latin1').decode(u8);
  let out = raw;
  let pos = 0;
  while ((pos = raw.indexOf('stream', pos)) >= 0) {
    let s = raw.indexOf('\n', pos) + 1; const e = raw.indexOf('endstream', s);
    if (s <= 0 || e < 0) break;
    const kopf = raw.slice(Math.max(0, pos - 400), pos);
    if (/FlateDecode/.test(kopf)) {
      try {
        const rd = new Blob([u8.slice(s, e)]).stream().pipeThrough(new DecompressionStream('deflate')).getReader();
        const dec = new TextDecoder('latin1');
        for (;;) { const { done, value } = await rd.read(); if (done) break; out += dec.decode(value, { stream: true }); }
      } catch (_) { /* Rest nach Fehler ignorieren */ }
    }
    pos = e + 9;
  }
  return out;
}
// Art: zuerst Dateiname (vvmwst / vvzoll), dann eingebettetes XML bzw. Überschrift im PDF
const artVon = (name: string, t: string) => /mwst|tva|vat/i.test(name) ? 'mwst' : /zoll|douane|dogana/i.test(name) ? 'zoll'
  : /taxationDecisionVAT|VERANLAGUNGSVERF\S*\s+MWST|D\S*CISION DE TAXATION TVA/i.test(t) ? 'mwst'
  : /taxationDecisionCustomsDuties|VERANLAGUNGSVERF\S*\s+ZOLL/i.test(t) ? 'zoll' : 'unbekannt';

// ---------------------------------------------------------------- Passar (B2B Hub Chartera Output v4)
// Token: Key Manager, Refresh mit Key/Secret (Basic) – Access 24 h, Refresh 7 Tage und wird jedes Mal ersetzt (sofort speichern).
// Meldungen: GET /v4/messages (Liste, JSON) → GET /v4/messages/{id} (DocumentPost-XML mit PDF/A-3 als Base64).
// PAIAD = Veranlagungsverfügung Einfuhr (enthält die MWST) → als 'mwst' wie die Mail-Verfügungen; CorrelationId = Nummer der Zollanmeldung.
const KEYMANAGER = 'https://keymanager.api.admin.ch/token/v2';
const HUB = 'https://charteraoutput-b2bhub.bazg.admin.ch/api/v4/messages';
const xmlFeld = (x: string, n: string) => (x.match(new RegExp(`<(?:\\w+:)?${n}>([\\s\\S]*?)</(?:\\w+:)?${n}>`)) || [])[1]?.trim() || '';

async function passarAbruf(admin: any) {
  const { data: p } = await admin.from('zoll_passar').select('*').eq('id', 1).maybeSingle();
  if (!p?.refresh_token) return { error: 'Passar nicht eingerichtet' };
  const fehler = async (text: string) => { await admin.from('zoll_passar').update({ letzter_fehler: text.slice(0, 500), fehler_seit: p.fehler_seit || new Date().toISOString() }).eq('id', 1); return { error: text }; };

  // Access Token alle ~6 Std. erneuern (BAZG empfiehlt 3–4× täglich), sonst wenn er bald abläuft
  let access = p.access_token as string | null;
  const alt = !p.access_von || Date.now() - new Date(p.access_von).getTime() > 6 * 3600e3;
  if (!access || alt || !p.access_bis || new Date(p.access_bis).getTime() - Date.now() < 3600e3) {
    let r: Response;
    try {
      r = await fetch(KEYMANAGER, { method: 'POST', signal: AbortSignal.timeout(70000),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', Authorization: 'Basic ' + btoa(`${p.client_key}:${p.client_secret}`) },
        body: new URLSearchParams({ grant_type: 'refresh_token', refresh_token: p.refresh_token }) });
    } catch (e) { return fehler('Key Manager nicht erreichbar: ' + String((e as any)?.message || e)); }
    const t = await r.json().catch(() => ({}));
    if (!r.ok || !t.access_token) return fehler(r.status === 401 ? 'Key oder Secret ungültig (401). Im API-Portal neuen Satz erzeugen und hier eintragen.'
      : r.status === 400 ? 'Refresh Token ungültig oder abgelaufen (400). Im API-Portal neuen Satz erzeugen und hier eintragen.'
      : `Token-Erneuerung fehlgeschlagen (${r.status}) ${t.error_description || t.error || ''}`.trim());
    const jetzt = Date.now();
    await admin.from('zoll_passar').update({ access_token: t.access_token, access_von: new Date(jetzt).toISOString(),
      access_bis: new Date(jetzt + (Number(t.expires_in) || 86400) * 1000).toISOString(),
      refresh_token: t.refresh_token || p.refresh_token,
      refresh_bis: new Date(jetzt + (Number(t.refresh_expires_in) || 7 * 86400) * 1000).toISOString() }).eq('id', 1);
    access = t.access_token;
  }

  const kopf = (accept: string) => ({ Authorization: 'Bearer ' + access, 'bp-id': p.bp_id, Accept: accept, 'Content-Type': accept });
  let zeiger = p.letzte_message_id as string | null, neu = 0, andere = 0, gelesen = 0;
  try {
    for (let runde = 0; runde < 5; runde++) {
      const url = HUB + '?size=50' + (zeiger ? '&lastMessageId=' + encodeURIComponent(zeiger) : '');
      const r = await fetch(url, { headers: kopf('application/json'), signal: AbortSignal.timeout(30000) });
      if (!r.ok) return fehler(`Meldungsliste ${r.status}: ${(await r.text()).slice(0, 200)}`);
      const liste = ((await r.json())?.messages || []) as any[];
      const offen = liste.filter((m) => m.messageId && m.messageId !== zeiger);
      if (!offen.length) break;
      for (const m of offen) {
        gelesen++;
        const schon = await admin.from('zoll_evv').select('id').eq('gmail_id', 'passar:' + m.messageId).maybeSingle();
        const typ = m.metadata?.documentType || '';
        if (!schon.data && /^document(post)?$/i.test(m.messageType || '') && (!typ || typ === 'PAIAD')) {
          const d = await fetch(`${HUB}/${encodeURIComponent(m.messageId)}`, { headers: kopf('application/xml'), signal: AbortSignal.timeout(30000) });
          if (!d.ok) return fehler(`Meldung ${m.messageId}: ${d.status}`);
          const x = await d.text();
          const dokTyp = xmlFeld(x, 'DocumentType'), daten = xmlFeld(x, 'DocumentData');
          if (dokTyp === 'PAIAD' && daten) {
            const nr = xmlFeld(x, 'CorrelationId') || m.metadata?.correlationId || null;
            const pfad = `${new Date().toISOString().slice(0, 7)}/${crypto.randomUUID()}.pdf`;
            const { error: eu } = await admin.storage.from('zoll').upload(pfad, b64(daten.replace(/\s+/g, '')), { contentType: 'application/pdf' });
            if (eu) return fehler('Ablage: ' + eu.message);
            await admin.from('zoll_evv').insert({ zanr: nr, art: 'mwst', quelle: 'passar', dateiname: xmlFeld(x, 'DocumentName') || `${nr}.pdf`,
              storage_pfad: pfad, gmail_id: 'passar:' + m.messageId, status: nr ? 'neu' : 'ohne_nummer' });
            neu++;
          } else andere++;
        } else if (!schon.data) andere++;
        zeiger = m.messageId;
        await admin.from('zoll_passar').update({ letzte_message_id: zeiger }).eq('id', 1);
      }
      if (liste.length < 50) break;
    }
  } catch (e) { return fehler('Abruf: ' + String((e as any)?.message || e)); }
  await admin.from('zoll_passar').update({ letzter_abruf: new Date().toISOString(), letzter_fehler: null, fehler_seit: null }).eq('id', 1);
  return { ok: true, gelesen, neu, andere };
}

async function googleEmail(token: string) {
  const r = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/profile', { headers: { Authorization: `Bearer ${token}` } });
  if (!r.ok) return null; const p = await r.json(); return String(p?.emailAddress || '').toLowerCase();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const body = await req.json().catch(() => ({}));

  // ---------------------------------------------------------------- Erweiterung
  if (body.aktion === 'offen' || body.aktion === 'ergebnis') {
    const email = body.googleAccessToken ? await googleEmail(body.googleAccessToken) : null;
    if (!email || !email.endsWith('@knechtgarten.ch')) return json({ error: 'Nur für @knechtgarten.ch-Konten.' }, 403);
    if (body.aktion === 'offen') {
      const jetzt = new Date().toISOString();
      const { data } = await admin.from('zoll_evv').select('id,zanr,dateiname,storage_pfad,in_arbeit_bis')
        .eq('status', 'neu').in('art', ['mwst', 'unbekannt']).not('zanr', 'is', null).order('erstellt_am').limit(20);
      const frei = (data || []).filter((r: any) => !r.in_arbeit_bis || r.in_arbeit_bis < jetzt);
      if (!frei.length) return json({ evv: [] });
      const bis = new Date(Date.now() + 3 * 60000).toISOString();
      await admin.from('zoll_evv').update({ in_arbeit_bis: bis, letzter_versuch: jetzt }).in('id', frei.map((r: any) => r.id));
      const evv = [];
      for (const r of frei) { const { data: u } = await admin.storage.from('zoll').createSignedUrl(r.storage_pfad, 600);
        if (u?.signedUrl) evv.push({ id: r.id, zanr: r.zanr, dateiname: r.dateiname, url: u.signedUrl }); }
      return json({ evv });
    }
    const { data: alt } = await admin.from('zoll_evv').select('versuche').eq('id', body.id).maybeSingle();
    const ae: any = { in_arbeit_bis: null, versuche: (alt?.versuche || 0) + 1, letzter_versuch: new Date().toISOString() };
    if (body.ergebnis === 'angehaengt') Object.assign(ae, { status: 'angehaengt', peax_doc_id: body.peax_doc_id || null, peax_titel: body.peax_titel || null,
      angehaengt_am: new Date().toISOString(), angehaengt_von: email, hinweis: null });
    else if (body.ergebnis === 'mehrdeutig') Object.assign(ae, { status: 'mehrdeutig', hinweis: String(body.hinweis || 'Mehrere passende Rechnungen in PEAX').slice(0, 300) });
    else ae.hinweis = String(body.hinweis || 'Rechnung noch nicht in PEAX').slice(0, 300);   // bleibt «neu», nächster Versuch später
    const { error } = await admin.from('zoll_evv').update(ae).eq('id', body.id);
    return error ? json({ error: error.message }, 500) : json({ ok: true });
  }

  if (body.aktion === 'passar') return json(await passarAbruf(admin));

  // ---------------------------------------------------------------- Abruf zoll@ (pg_cron)
  if (body.aktion !== 'abruf') return json({ error: 'Unbekannte Aktion' }, 400);
  const { data: u } = await admin.from('benutzer').select('id').eq('email', KONTO).maybeSingle();
  const { data: v } = u ? await admin.from('google_verbindung').select('refresh_token,scope').eq('benutzer_id', u.id).maybeSingle() : { data: null };
  if (!v || !/gmail/.test(v.scope || '')) return json({ error: 'Keine Gmail-Verbindung für ' + KONTO });
  const t = await (await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ refresh_token: v.refresh_token, client_id: CLIENT_ID, client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!, grant_type: 'refresh_token' }) })).json();
  if (!t.access_token) return json({ error: 'Google-Token fehlgeschlagen' });
  const gmail = async (pfad: string) => { const r = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/' + pfad, { headers: { Authorization: 'Bearer ' + t.access_token } });
    if (!r.ok) throw new Error('Gmail ' + r.status); return r.json(); };

  const q = `newer_than:14d {to:${ADRESSE} cc:${ADRESSE} bcc:${ADRESSE} deliveredto:${ADRESSE}}`;
  const liste = await gmail('messages?maxResults=25&q=' + encodeURIComponent(q));
  const ids: string[] = (liste.messages || []).map((m: any) => m.id);
  if (!ids.length) return json({ neu: 0 });
  const { data: schon } = await admin.from('zoll_mail').select('gmail_id').in('gmail_id', ids);
  const offen = ids.filter((id) => !(schon || []).some((s: any) => s.gmail_id === id)).slice(0, 8);

  let neu = 0;
  for (const id of offen) {
    let von = '', betreff = '';
    try {
      const m = await gmail('messages/' + id + '?format=full');
      const H = (n: string) => (m.payload.headers || []).filter((h: any) => h.name.toLowerCase() === n).map((h: any) => h.value).join(', ');
      von = H('from'); betreff = H('subject');
      const absender = (von.toLowerCase().match(/[a-z0-9._%+-]+@[a-z0-9.-]+/) || [''])[0];
      if (!absender.endsWith('@knechtgarten.ch') && !absender.endsWith('.admin.ch')) {
        await admin.from('zoll_mail').insert({ gmail_id: id, von, betreff, status: 'abgelehnt', fehler: 'fremder Absender' }); continue; }
      const tl = teile(m.payload);
      const plain = tl.find((p) => p.mimeType === 'text/plain' && p.body?.data && !p.filename);
      const mailText = betreff + '\n' + (plain ? textAus(plain.body.data) : m.snippet || '');
      const pdfs = tl.filter((p) => p.filename && p.body?.attachmentId && (/pdf/i.test(p.mimeType) || /\.pdf$/i.test(p.filename)));
      if (!pdfs.length) { await admin.from('zoll_mail').insert({ gmail_id: id, von, betreff, status: 'ohne_pdf' }); continue; }
      for (const a of pdfs) {
        const d = await gmail(`messages/${id}/attachments/${a.body.attachmentId}`);
        const daten = b64(d.data), inhalt = await pdfText(daten);
        const nr = [...new Set([...(a.filename.match(ZANR) || []), ...(inhalt.match(ZANR) || [])])];
        const zanr = nr.length === 1 ? nr[0] : (a.filename.match(ZANR) || [])[0] || (nr.length ? null : (mailText.match(ZANR) || [])[0] || null);
        const art = artVon(a.filename, inhalt);
        const pfad = `${new Date().toISOString().slice(0, 7)}/${crypto.randomUUID()}.pdf`;
        const { error: eu } = await admin.storage.from('zoll').upload(pfad, daten, { contentType: 'application/pdf' }); if (eu) throw eu;
        await admin.from('zoll_evv').insert({ zanr, art, quelle: 'mail', dateiname: a.filename, storage_pfad: pfad, gmail_id: id,
          status: zanr ? 'neu' : 'ohne_nummer', hinweis: !zanr && nr.length > 1 ? 'Mehrere Nummern im PDF: ' + nr.join(', ') : null });
        neu++;
      }
      await admin.from('zoll_mail').insert({ gmail_id: id, von, betreff, status: 'ok' });
    } catch (e) {
      await admin.from('zoll_mail').insert({ gmail_id: id, von, betreff, status: 'fehler', fehler: String((e as any)?.message || e).slice(0, 500) });
    }
  }
  return json({ neu, geprueft: offen.length });
});
