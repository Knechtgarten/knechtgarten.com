// Pendenzen per Mail: holt neue Mails an vorname.pendenzen@knechtgarten.ch (Aliase am Konto mail@knechtgarten.ch)
// über Gmail und macht daraus Pendenzen in der Liste «Mails» des passenden Boards (pendenz_board.mail_kuerzel).
// Titel = Betreff, Notiz = Mailtext, Dateien = das Mail als PDF + jeder Anhang einzeln.
// Nur Absender @knechtgarten.ch (weitergeleitete Kundenmails kommen so auch durch). Aufruf alle 2 Minuten per pg_cron.
// Gibt nur Anzahlen zurück; jedes Mail wird in pendenz_mail vermerkt und nie doppelt verarbeitet.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1';

const CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';
const KONTO = 'mail@knechtgarten.ch', DOMAIN = '@knechtgarten.ch', ENDUNG = '.pendenzen@knechtgarten.ch';
const BUCKET = 'pendenz-dateien';
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { 'Content-Type': 'application/json' } });

const b64 = (s: string) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const textAus = (s: string) => new TextDecoder().decode(b64(s));
const adressen = (s: string) => (String(s || '').toLowerCase().match(/[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/g) || []);
const htmlZuText = (h: string) => h.replace(/<style[\s\S]*?<\/style>/gi, '').replace(/<br\s*\/?>/gi, '\n').replace(/<\/(p|div|tr|li|h\d)>/gi, '\n')
  .replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
  .replace(/\n{3,}/g, '\n\n').trim();
const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
// Helvetica (WinAnsi) kann nicht alles: Sonderzeichen ersetzen statt abstürzen
const winAnsi = (s: string) => s.replace(/[‘’]/g, "'").replace(/[“”„]/g, '"').replace(/[–—]/g, '-').replace(/…/g, '...')
  .replace(/\t/g, '    ').replace(/[^\x0A\x20-\x7E\xA0-\xFF€]/g, '');

// alle Teile eines Mails flach durchgehen
const teile = (p: any, out: any[] = []) => { out.push(p); (p.parts || []).forEach((c: any) => teile(c, out)); return out; };

async function mailPdf(kopf: [string, string][], text: string) {
  const doc = await PDFDocument.create(), f = await doc.embedFont(StandardFonts.Helvetica), fb = await doc.embedFont(StandardFonts.HelveticaBold);
  const B = 595, H = 842, R = 50, breite = B - 2 * R, gr = 10, zh = 14;
  let page = doc.addPage([B, H]), y = H - R;
  const neu = () => { page = doc.addPage([B, H]); y = H - R; };
  const zeile = (t: string, font = f, size = gr, farbe = rgb(0.14, 0.17, 0.21)) => { if (y < R) neu(); page.drawText(t, { x: R, y, size, font, color: farbe }); y -= zh; };
  const umbrechen = (t: string, font = f, size = gr) => {
    for (const absatz of winAnsi(t).split('\n')) {
      let z = '';
      for (const w of absatz.split(' ')) {
        const v = z ? z + ' ' + w : w;
        if (font.widthOfTextAtSize(v, size) > breite && z) { zeile(z, font, size); z = w; } else z = v;
        while (font.widthOfTextAtSize(z, size) > breite) { let n = z.length; while (n > 1 && font.widthOfTextAtSize(z.slice(0, n), size) > breite) n--; zeile(z.slice(0, n), font, size); z = z.slice(n); }
      }
      zeile(z, font, size);
    }
  };
  for (const [k, v] of kopf) { if (!v) continue; if (y < R) neu(); page.drawText(winAnsi(k + ':'), { x: R, y, size: gr, font: fb, color: rgb(0.42, 0.44, 0.47) });
    const rest = winAnsi(v); let z = rest; while (f.widthOfTextAtSize(z, gr) > breite - 70 && z.length > 3) z = z.slice(0, -2); page.drawText(z, { x: R + 70, y, size: gr, font: f }); y -= zh; }
  y -= 6; page.drawLine({ start: { x: R, y: y + 8 }, end: { x: B - R, y: y + 8 }, thickness: 0.5, color: rgb(0.85, 0.87, 0.89) }); y -= 6;
  umbrechen(text || '(kein Text)');
  return await doc.save();
}

Deno.serve(async () => {
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  // Google-Zugang des Kontos mail@knechtgarten.ch
  const { data: u } = await admin.from('benutzer').select('id').eq('email', KONTO).maybeSingle();
  const { data: v } = u ? await admin.from('google_verbindung').select('refresh_token,scope').eq('benutzer_id', u.id).maybeSingle() : { data: null };
  if (!v) return json({ error: 'Keine Google-Verbindung für ' + KONTO });
  if (!/gmail/.test(v.scope || '')) return json({ error: 'Google-Verbindung ohne Gmail-Zugriff' });
  const t = await (await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ refresh_token: v.refresh_token, client_id: CLIENT_ID, client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!, grant_type: 'refresh_token' }) })).json();
  if (!t.access_token) return json({ error: 'Google-Token fehlgeschlagen' });
  const gmail = async (pfad: string) => { const r = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/' + pfad, { headers: { Authorization: 'Bearer ' + t.access_token } });
    if (!r.ok) throw new Error('Gmail ' + r.status + ' ' + (await r.text()).slice(0, 200)); return r.json(); };

  // Boards mit Mail-Kürzel → Adresse
  const { data: boards } = await admin.from('pendenz_board').select('id,besitzer_id,mail_kuerzel').not('mail_kuerzel', 'is', null);
  const ZIEL = new Map((boards || []).map((b: any) => [b.mail_kuerzel + ENDUNG, b]));
  if (!ZIEL.size) return json({ neu: 0 });
  const q = 'newer_than:3d {' + [...ZIEL.keys()].map((a) => `to:${a} cc:${a} bcc:${a}`).join(' ') + '}';
  const liste = await gmail('messages?maxResults=25&q=' + encodeURIComponent(q));
  const ids: string[] = (liste.messages || []).map((m: any) => m.id);
  if (!ids.length) return json({ neu: 0 });
  const { data: schon } = await admin.from('pendenz_mail').select('gmail_id').in('gmail_id', ids);
  const offen = ids.filter((id) => !(schon || []).some((s: any) => s.gmail_id === id)).slice(0, 8);

  let neu = 0;
  for (const id of offen.reverse()) {   // älteste zuerst
    let von = '', an = '', betreff = '';
    try {
      const m = await gmail('messages/' + id + '?format=full');
      const H = (n: string) => (m.payload.headers || []).filter((h: any) => h.name.toLowerCase() === n.toLowerCase()).map((h: any) => h.value).join(', ');
      von = H('From'); betreff = H('Subject'); const datum = H('Date');
      const alle = adressen([H('To'), H('Cc'), H('Delivered-To'), H('X-Original-To'), H('X-Forwarded-To')].join(' '));
      an = alle.find((a) => ZIEL.has(a)) || '';
      const absender = adressen(von)[0] || '';
      if (!an) { await admin.from('pendenz_mail').insert({ gmail_id: id, von, betreff, status: 'abgelehnt', fehler: 'keine Pendenzen-Adresse gefunden' }); continue; }
      if (!absender.endsWith(DOMAIN)) { await admin.from('pendenz_mail').insert({ gmail_id: id, an, von, betreff, status: 'abgelehnt', fehler: 'fremder Absender' }); continue; }
      const board: any = ZIEL.get(an);

      // Text: lieber text/plain, sonst aus HTML
      const tl = teile(m.payload);
      const plain = tl.find((p) => p.mimeType === 'text/plain' && p.body?.data && !p.filename), html = tl.find((p) => p.mimeType === 'text/html' && p.body?.data && !p.filename);
      const text = (plain ? textAus(plain.body.data) : html ? htmlZuText(textAus(html.body.data)) : (m.snippet || '')).replace(/\r/g, '').trim();

      // Ziel-Liste: «Mails» im Board, sonst Sammelbox/Team, sonst erste Liste
      const { data: ls } = await admin.from('pendenz_liste').select('id,art_id,zeit,erstellt_am').eq('board_id', board.id).order('erstellt_am');
      const l = (ls || []).find((x: any) => x.art_id === 'mail') || (ls || []).find((x: any) => x.art_id === 'team') || (ls || [])[0];
      if (!l) throw new Error('Board ohne Liste');
      const { data: mx } = await admin.from('pendenz').select('sortierung').eq('liste_id', l.id).order('sortierung', { ascending: false }).limit(1);
      const titel = (betreff || '').replace(/^\s*((fwd?|wg|aw|re|tr)\s*:\s*)+/i, '').trim() || '(ohne Betreff)';
      const notiz = text ? `<p>${esc(text.slice(0, 20000)).replace(/\n\n+/g, '</p><p>').replace(/\n/g, '<br>')}</p>` : null;
      const { data: p, error } = await admin.from('pendenz').insert({ liste_id: l.id, titel: titel.slice(0, 300), notiz, zeit: l.zeit || 0, sortierung: ((mx || [])[0]?.sortierung || 0) + 1,
        herkunft: 'mail', erstellt_von: board.besitzer_id || null }).select('id').single();
      if (error) throw error;

      // Dateien: Mail als PDF, dann jeder Anhang
      const ablegen = async (name: string, daten: Uint8Array, typ: string, art: string) => {
        const did = crypto.randomUUID(), ext = (name.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '') || 'bin', pfad = `${p.id}/${did}.${ext}`;
        const { error: eu } = await admin.storage.from(BUCKET).upload(pfad, daten, { contentType: typ || 'application/octet-stream' }); if (eu) throw eu;
        await admin.from('pendenz_datei').insert({ id: did, pendenz_id: p.id, art, name, storage_pfad: pfad });
      };
      const pdf = await mailPdf([['Von', von], ['An', H('To')], ['Cc', H('Cc')], ['Datum', datum], ['Betreff', betreff]], text);
      await ablegen(`Mail ${titel.replace(/[\\/:*?"<>|]/g, '').slice(0, 80)}.pdf`, pdf, 'application/pdf', 'mail');
      for (const a of tl.filter((x) => x.filename && x.body?.attachmentId)) {
        const inline = /inline/i.test((a.headers || []).find((h: any) => h.name.toLowerCase() === 'content-disposition')?.value || '');
        if (inline && /^image\//.test(a.mimeType) && (a.body.size || 0) < 30000) continue;   // Logos in Signaturen weglassen
        const d = await gmail(`messages/${id}/attachments/${a.body.attachmentId}`);
        await ablegen(a.filename, b64(d.data), a.mimeType, /^image\//.test(a.mimeType) ? 'foto' : 'datei');
      }
      await admin.from('pendenz_mail').insert({ gmail_id: id, pendenz_id: p.id, an, von, betreff, status: 'ok' });
      neu++;
    } catch (e) {
      await admin.from('pendenz_mail').insert({ gmail_id: id, an, von, betreff, status: 'fehler', fehler: String((e as any)?.message || e).slice(0, 500) });
    }
  }
  return json({ neu, geprueft: offen.length });
});
