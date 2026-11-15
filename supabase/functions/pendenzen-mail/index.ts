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

  // Mail → Pendenz in der Liste «Mails» des Boards (Titel = Betreff, Notiz = Text, Dateien = Mail-PDF + Anhänge)
  async function pendenzAusMail(m: any, board: any, herkunft: string) {
    const id = m.id;
    const H = (n: string) => (m.payload.headers || []).filter((h: any) => h.name.toLowerCase() === n.toLowerCase()).map((h: any) => h.value).join(', ');
    const von = H('From'), betreff = H('Subject'), datum = H('Date');
    {
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
        herkunft, erstellt_von: board.besitzer_id || null }).select('id').single();
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
      return { pendenz_id: p.id, von, betreff };
    }
  }

  // ===== 1) Mails an vorname.pendenzen@knechtgarten.ch =====
  const { data: boards } = await admin.from('pendenz_board').select('id,besitzer_id,mail_kuerzel').not('mail_kuerzel', 'is', null);
  const ZIEL = new Map((boards || []).map((b: any) => [b.mail_kuerzel + ENDUNG, b]));
  let neu = 0, geprueft = 0;
  if (ZIEL.size) {
    const q = 'newer_than:3d {' + [...ZIEL.keys()].map((a) => `to:${a} cc:${a} bcc:${a}`).join(' ') + '}';
    const liste = await gmail('messages?maxResults=25&q=' + encodeURIComponent(q));
    const ids: string[] = (liste.messages || []).map((m: any) => m.id);
    const { data: schon } = ids.length ? await admin.from('pendenz_mail').select('gmail_id').in('gmail_id', ids) : { data: [] as any[] };
    const offen = ids.filter((id) => !(schon || []).some((s: any) => s.gmail_id === id)).slice(0, 8);
    geprueft = offen.length;
    for (const id of offen.reverse()) {   // älteste zuerst
      let von = '', an = '', betreff = '';
      try {
        const m = await gmail('messages/' + id + '?format=full');
        const H = (n: string) => (m.payload.headers || []).filter((h: any) => h.name.toLowerCase() === n.toLowerCase()).map((h: any) => h.value).join(', ');
        von = H('From'); betreff = H('Subject');
        an = adressen([H('To'), H('Cc'), H('Delivered-To'), H('X-Original-To'), H('X-Forwarded-To')].join(' ')).find((a) => ZIEL.has(a)) || '';
        const absender = adressen(von)[0] || '';
        if (!an) { await admin.from('pendenz_mail').insert({ gmail_id: id, von, betreff, status: 'abgelehnt', fehler: 'keine Pendenzen-Adresse gefunden' }); continue; }
        if (!absender.endsWith(DOMAIN)) { await admin.from('pendenz_mail').insert({ gmail_id: id, an, von, betreff, status: 'abgelehnt', fehler: 'fremder Absender' }); continue; }
        const r = await pendenzAusMail(m, ZIEL.get(an), 'mail');
        await admin.from('pendenz_mail').insert({ gmail_id: id, pendenz_id: r.pendenz_id, an, von, betreff, status: 'ok' });
        neu++;
      } catch (e) {
        await admin.from('pendenz_mail').insert({ gmail_id: id, an, von, betreff, status: 'fehler', fehler: String((e as any)?.message || e).slice(0, 500) });
      }
    }
  }

  // ===== 2) Gmail-Stern ↔ Pendenz (zweiseitig) für das Board des Kontos mail@ =====
  // Stern gesetzt → Pendenz in «Mails» (Stern-Icon); Stern weg → Pendenz archiviert; Pendenz archiviert/gelöscht → Stern weg (braucht gmail.modify).
  // Beim allerersten Lauf werden alle schon markierten Mails nur vermerkt (stern_alt), damit nicht alte Sterne auf einmal kommen.
  const stern: any = { neu: 0, archiviert: 0, entsternt: 0 };
  const sternBoard: any = (boards || []).find((b: any) => b.besitzer_id === u!.id);
  if (sternBoard) {
    try {
      const markiert: string[] = []; let tok = '';
      do { const r = await gmail('messages?maxResults=500&labelIds=STARRED' + (tok ? '&pageToken=' + tok : '')); (r.messages || []).forEach((m: any) => markiert.push(m.id)); tok = r.nextPageToken || ''; } while (tok && markiert.length < 30000);   // alle Sterne (sonst falsch als «weg» bzw. «neu» erkannt)
      const setM = new Set(markiert);
      // alle bekannten Mails seitenweise (eine in()-Abfrage mit tausenden IDs wäre zu lang)
      const BEK = new Map<string, string>();
      for (let von = 0; ; von += 1000) { const { data: s } = await admin.from('pendenz_mail').select('gmail_id,status').range(von, von + 999); (s || []).forEach((x: any) => BEK.set(x.gmail_id, x.status)); if (!s || s.length < 1000) break; }
      const bekannt = [...BEK.values()].some((s) => s.startsWith('stern'));
      if (!bekannt) {
        // Start: vorhandene Sterne nur vermerken (Mails, die schon als Alias-Pendenz da sind, bleiben unberührt)
        const rows: any[] = markiert.filter((id) => !BEK.has(id)).map((id) => ({ gmail_id: id, status: 'stern_alt' }));
        rows.push({ gmail_id: 'stern-start-' + Date.now(), status: 'stern_alt' });   // Marker, falls gerade nichts markiert ist
        for (let i = 0; i < rows.length; i += 200) await admin.from('pendenz_mail').insert(rows.slice(i, i + 200));
        stern.start = rows.length - 1;
      } else {
        // a) neu markiert
        // wieder markiert, nachdem die Pendenz schon erledigt war → als neue Pendenz behandeln
        const wieder = markiert.filter((id) => BEK.get(id) === 'stern_weg');
        if (wieder.length) await admin.from('pendenz_mail').delete().in('gmail_id', wieder.slice(0, 50));
        const frisch = markiert.filter((id) => wieder.includes(id) || !BEK.has(id)).slice(0, 8);
        for (const id of frisch.reverse()) {
          try {
            const m = await gmail('messages/' + id + '?format=full');
            const r = await pendenzAusMail(m, sternBoard, 'stern');
            await admin.from('pendenz_mail').insert({ gmail_id: id, pendenz_id: r.pendenz_id, an: KONTO, von: r.von, betreff: r.betreff, status: 'stern' });
            stern.neu++;
          } catch (e) { await admin.from('pendenz_mail').insert({ gmail_id: id, an: KONTO, status: 'fehler', fehler: 'Stern: ' + String((e as any)?.message || e).slice(0, 480) }); }
        }
        // b) aktive Stern-Pendenzen abgleichen
        const { data: aktiv } = await admin.from('pendenz_mail').select('gmail_id,pendenz_id').eq('status', 'stern');
        const pids = (aktiv || []).map((x: any) => x.pendenz_id).filter(Boolean);
        const { data: pz } = pids.length ? await admin.from('pendenz').select('id,erledigt').in('id', pids) : { data: [] as any[] };
        const darfAendern = /gmail\.modify/.test(v.scope || '');
        for (const a of (aktiv || []) as any[]) {
          const p: any = (pz || []).find((x: any) => x.id === a.pendenz_id), offenP = !!p && !p.erledigt;
          if (offenP && !setM.has(a.gmail_id)) {          // Stern in Gmail entfernt → Pendenz archivieren
            await admin.from('pendenz').update({ erledigt: true, erledigt_am: new Date().toISOString() }).eq('id', p.id);
            await admin.from('pendenz_mail').update({ status: 'stern_weg' }).eq('gmail_id', a.gmail_id); stern.archiviert++;
          } else if (!offenP && setM.has(a.gmail_id)) {   // Pendenz archiviert/gelöscht → Stern in Gmail entfernen
            if (!darfAendern) { stern.ohneRecht = true; continue; }
            const r = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${a.gmail_id}/modify`, { method: 'POST',
              headers: { Authorization: 'Bearer ' + t.access_token, 'Content-Type': 'application/json' }, body: JSON.stringify({ removeLabelIds: ['STARRED'] }) });
            if (r.ok) { await admin.from('pendenz_mail').update({ status: 'stern_weg' }).eq('gmail_id', a.gmail_id); stern.entsternt++; }
            else stern.fehler = 'Stern entfernen: ' + r.status;
          } else if (!offenP && !setM.has(a.gmail_id)) {  // beides erledigt
            await admin.from('pendenz_mail').update({ status: 'stern_weg' }).eq('gmail_id', a.gmail_id);
          }
        }
      }
    } catch (e) { stern.fehler = String((e as any)?.message || e).slice(0, 300); }
  }
  return json({ neu, geprueft, stern });
});
