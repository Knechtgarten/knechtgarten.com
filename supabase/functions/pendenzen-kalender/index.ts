// Pendenzen ↔ Google-Kalender «Pendenzen» (pro Person, eigener Kalender).
// Alle 2 Minuten per pg_cron:
//  1) Mitwandern: offene Pendenzen mit vergangenem Datum bekommen das heutige (Sa/So: den Montag), «seit» merkt das erste Datum.
//     Pendenzen in «Heute» ohne Datum bekommen heute, Pendenzen mit Datum heute kommen nach «Heute».
//  2) Pro Tag mit offenen Pendenzen ein Sammeltermin 05:00–15:00: Titel «N Pendenzen • kurz • kurz …», Beschreibung = saubere Liste.
//     In Google verschoben/verlängert → Zeit bleibt so. Im Kalender gelöscht → Pendenzen verlieren das Datum (bleiben im Tool).
//     Keine offenen Pendenzen mehr an dem Tag → Termin weg.
// Nur für Personen, deren Google-Verbindung das Recht «calendar» hat. Google zeigt nur an – erledigt wird im Pendenzentool.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';
const TZ = 'Europe/Zurich', START = '05:00:00', ENDE = '15:00:00', TOOL = 'https://knechtgarten.com/pendenzen-live-v1.html';
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { 'Content-Type': 'application/json' } });

// Datum in Zürich als JJJJ-MM-TT
const tagZh = (d = new Date()) => new Intl.DateTimeFormat('sv-SE', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
const plusTage = (tag: string, n: number) => { const d = new Date(tag + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const wochentag = (tag: string) => new Date(tag + 'T12:00:00Z').getUTCDay();   // 0 = So, 6 = Sa
const WT = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];
const kurzDatum = (tag: string) => `${WT[wochentag(tag)]} ${Number(tag.slice(8, 10))}.${Number(tag.slice(5, 7))}.`;
const kuerzen = (s: string, n: number) => { const t = String(s || '').replace(/\s+/g, ' ').trim(); return t.length > n ? t.slice(0, n - 1).trimEnd() + '…' : t; };
const hash = async (s: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-1', new TextEncoder().encode(s)))).map((b) => b.toString(16).padStart(2, '0')).join('');

Deno.serve(async () => {
  const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const heute = tagZh(), wt = wochentag(heute);
  const ziel = wt === 6 ? plusTage(heute, 2) : wt === 0 ? plusTage(heute, 1) : heute;   // Wochenende: nichts wandert, Freitag → Montag
  const { data: verb } = await admin.from('google_verbindung').select('benutzer_id,refresh_token,scope');
  const leute = (verb || []).filter((v: any) => /auth\/calendar/.test(v.scope || ''));
  const bericht: any[] = [];

  for (const v of leute as any[]) {
    const r: any = { benutzer: v.benutzer_id, gewandert: 0, neu: 0, geaendert: 0, weg: 0 };
    try {
      // eigenes Board (Person) und seine Listen
      const { data: boards } = await admin.from('pendenz_board').select('id').eq('besitzer_id', v.benutzer_id).eq('typ', 'person');
      const bids = (boards || []).map((b: any) => b.id); if (!bids.length) { r.info = 'kein eigenes Board'; bericht.push(r); continue; }
      const { data: ls } = await admin.from('pendenz_liste').select('id,zeit').in('board_id', bids);
      const lids = (ls || []).map((l: any) => l.id), heuteListe = (ls || []).find((l: any) => l.zeit === 1);
      const { data: pz } = lids.length ? await admin.from('pendenz').select('id,titel,datum,datum_seit,zeit,erstellt_am,sortierung,zeit_sortierung').in('liste_id', lids).eq('erledigt', false) : { data: [] as any[] };
      const P = (pz || []) as any[];

      // 1) Mitwandern / Heute ↔ Datum
      for (const p of P) {
        const patch: any = {};
        if (p.datum && p.datum < heute) { patch.datum = ziel; patch.datum_seit = p.datum_seit || p.datum; r.gewandert++; }
        else if (!p.datum && p.zeit === 1) patch.datum = heute;
        const d = patch.datum || p.datum;
        if (d === heute && p.zeit !== 1) patch.zeit = 1;
        if (Object.keys(patch).length) { Object.assign(p, patch); await admin.from('pendenz').update(patch).eq('id', p.id); }
      }

      // Google-Zugang
      const t = await (await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ refresh_token: v.refresh_token, client_id: CLIENT_ID, client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!, grant_type: 'refresh_token' }) })).json();
      if (!t.access_token) throw new Error('Google-Token: ' + (t.error_description || t.error));
      const gcal = async (pfad: string, opt: any = {}) => { const res = await fetch('https://www.googleapis.com/calendar/v3/' + pfad, { ...opt, headers: { Authorization: 'Bearer ' + t.access_token, 'Content-Type': 'application/json', ...(opt.headers || {}) } });
        if (res.status === 404 || res.status === 410) return { _weg: true }; if (res.status === 204) return {}; const d = await res.json().catch(() => ({})); if (!res.ok) throw new Error('Kalender ' + res.status + ' ' + JSON.stringify(d).slice(0, 200)); return d; };

      // Kalender «Pendenzen» (einmal anlegen)
      let { data: kk } = await admin.from('pendenz_kalender_konto').select('calendar_id').eq('benutzer_id', v.benutzer_id).maybeSingle();
      if (kk) { const c = await gcal('calendars/' + encodeURIComponent(kk.calendar_id)); if (c._weg) { await admin.from('pendenz_kalender_konto').delete().eq('benutzer_id', v.benutzer_id); kk = null; } }
      if (!kk) { const c = await gcal('calendars', { method: 'POST', body: JSON.stringify({ summary: 'Pendenzen', description: 'Aus dem Knechtgarten-Pendenzentool – erledigt wird im Tool.', timeZone: TZ }) });
        await admin.from('pendenz_kalender_konto').insert({ benutzer_id: v.benutzer_id, calendar_id: c.id }); kk = { calendar_id: c.id }; r.kalenderNeu = true; }
      const cal = encodeURIComponent(kk!.calendar_id);

      // 2) Sammeltermine pro Tag
      const proTag = new Map<string, any[]>();
      for (const p of P) if (p.datum && p.datum >= heute && p.datum <= plusTage(heute, 120)) { if (!proTag.has(p.datum)) proTag.set(p.datum, []); proTag.get(p.datum)!.push(p); }
      const { data: tage } = await admin.from('pendenz_kalender_tag').select('*').eq('benutzer_id', v.benutzer_id);
      const T = new Map((tage || []).map((x: any) => [x.tag, x]));
      const alle = new Set([...proTag.keys(), ...[...T.keys()].filter((d: any) => d >= heute)]);
      for (const tag of alle) {
        const liste = (proTag.get(tag) || []).sort((a, b) => (a.zeit_sortierung ?? 1e12) - (b.zeit_sortierung ?? 1e12) || a.sortierung - b.sortierung || a.erstellt_am.localeCompare(b.erstellt_am));
        const row: any = T.get(tag);
        if (!liste.length) { if (row) { await gcal(`calendars/${cal}/events/${row.event_id}`, { method: 'DELETE' }); await admin.from('pendenz_kalender_tag').delete().eq('benutzer_id', v.benutzer_id).eq('tag', tag); r.weg++; } continue; }
        const n = liste.length;
        const titel = `${n} ${n === 1 ? 'Pendenz' : 'Pendenzen'} • ` + liste.map((p) => kuerzen(p.titel, 38)).join(' • ');
        const beschreibung = liste.map((p) => `☐ ${p.titel}${p.datum_seit && p.datum_seit < tag ? ` (seit ${kurzDatum(p.datum_seit)})` : ''}`).join('\n') + `\n\nErledigen im Pendenzentool: ${TOOL}`;
        const h = await hash(titel + '|' + beschreibung);
        const zeit = { start: { dateTime: `${tag}T${START}`, timeZone: TZ }, end: { dateTime: `${tag}T${ENDE}`, timeZone: TZ } };
        if (!row) {
          const e = await gcal(`calendars/${cal}/events`, { method: 'POST', body: JSON.stringify({ summary: titel, description: beschreibung, ...zeit, transparency: 'transparent', reminders: { useDefault: false } }) });
          await admin.from('pendenz_kalender_tag').insert({ benutzer_id: v.benutzer_id, tag, event_id: e.id, start_ts: e.start?.dateTime, ende_ts: e.end?.dateTime, inhalt_hash: h }); r.neu++; continue;
        }
        const e = await gcal(`calendars/${cal}/events/${row.event_id}`);
        if (e._weg || e.status === 'cancelled') {
          // im Kalender gelöscht → Pendenzen dieses Tages verlieren das Datum (heute: auch raus aus «Heute»)
          for (const p of liste) { const patch: any = { datum: null, datum_seit: null }; if (tag === heute && p.zeit === 1) patch.zeit = 0; await admin.from('pendenz').update(patch).eq('id', p.id); }
          await admin.from('pendenz_kalender_tag').delete().eq('benutzer_id', v.benutzer_id).eq('tag', tag); r.geloeschtInGoogle = (r.geloeschtInGoogle || 0) + 1; continue;
        }
        const manuell = row.manuell || (row.start_ts && (e.start?.dateTime !== row.start_ts || e.end?.dateTime !== row.ende_ts));
        if (h !== row.inhalt_hash || manuell !== row.manuell) {
          if (h !== row.inhalt_hash) await gcal(`calendars/${cal}/events/${row.event_id}`, { method: 'PATCH', body: JSON.stringify({ summary: titel, description: beschreibung }) });
          await admin.from('pendenz_kalender_tag').update({ inhalt_hash: h, manuell, start_ts: e.start?.dateTime, ende_ts: e.end?.dateTime, geaendert_am: new Date().toISOString() }).eq('benutzer_id', v.benutzer_id).eq('tag', tag); r.geaendert++;
        }
      }
      // vergangene Tage: die offenen Pendenzen sind weitergewandert → alter Sammeltermin weg (im Kalender steht nur, was noch offen ist)
      for (const [tag, row] of T as Map<string, any>) if (tag < heute) {
        await gcal(`calendars/${cal}/events/${row.event_id}`, { method: 'DELETE' });
        await admin.from('pendenz_kalender_tag').delete().eq('benutzer_id', v.benutzer_id).eq('tag', tag);
      }
    } catch (e) { r.fehler = String((e as any)?.message || e).slice(0, 300); }
    bericht.push(r);
  }
  return json({ heute, ziel, bericht });
});
