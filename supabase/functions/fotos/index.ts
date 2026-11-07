// ============================================================================
// Fotos Baustelle (Handy der Mitarbeiter): Fotos in den Kundenordner im Google Drive ablegen,
// Unterordner «22-Fotos-Bauablauf und Schluss» im Ordner des aktuellen Jahres.
// Die Mitarbeiter brauchen keinen eigenen Google-Zugang: abgelegt wird über die Google-Verbindung
// des Firmenkontos (mail@knechtgarten.ch, Refresh-Token in google_verbindung, wie in doku-google).
// Aktionen:
//   { aktion: 'ziele', lat?, lon? }        → Einsätze heute (Planer) mit Distanz zum Standort
//   { aktion: 'suche', q }                  → Kunden suchen (Name, Ort, Strasse)
//   { aktion: 'vorbereiten', kunde_id, dateien: [{ name, typ, groesse }], origin }
//        → Ordner einmal suchen/anlegen, pro Foto eine Upload-Sitzung bei Google; das Handy lädt die Bytes
//          direkt dorthin (schnell, parallel, kein base64 über den Server). Die Sitzung erlaubt nur genau diese Datei.
//   { aktion: 'erfasst', kunde_id, ordner_id, dateien: [{ id, name }], lat?, lon? } → in foto_ablage festhalten
//   { aktion: 'hochladen', kunde_id, dateiname, typ, daten (base64), lat?, lon? } → alter Weg (Warteschlange ohne Netz)
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';
const FIRMENKONTO = 'mail@knechtgarten.ch';
const ROOT = '0AEZm9ALFx3sgUk9PVA', VORLAGE = '12hH-QP2_RZ559nmmxG_ZsKCrazUh6pon', ORDNER = 'application/vnd.google-apps.folder';
const KFELDER = 'id,name,vorname,nachname,firma,strasse,plz,ort,geo_lat,geo_lon';

const tagZh = (d: Date) => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Zurich' }).format(d);   // YYYY-MM-DD
const distanz = (a: number, b: number, c: number, d: number) => { const R = 6371000, r = Math.PI / 180, x = (c - a) * r, y = (d - b) * r;
  const h = Math.sin(x / 2) ** 2 + Math.cos(a * r) * Math.cos(c * r) * Math.sin(y / 2) ** 2; return 2 * R * Math.asin(Math.sqrt(h)); };
const ortOhnePlz = (o: string) => String(o || '').replace(/^\d{4}\s*/, '').trim();
const kName = (k: any) => k.name || [k.vorname, k.nachname].filter(Boolean).join(' ') || k.firma || 'Kunde';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const nutzer = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: { user } } = await nutzer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: ich } = await admin.from('benutzer').select('id,anzeigename,email,rolle,aktiv').eq('id', user.id).maybeSingle();
    if (!ich?.rolle || ich.aktiv === false) return json({ error: 'Konto nicht freigeschaltet.' }, 403);
    const body = await req.json();

    // Koordinaten eines Kunden (geo.admin), einmal gemerkt
    const koordinaten = async (k: any) => {
      if (k.geo_lat && k.geo_lon) return k;
      const adr = [k.strasse, [k.plz, ortOhnePlz(k.ort)].filter(Boolean).join(' ')].filter(Boolean).join(', ');
      if (!k.strasse || !adr) return k;
      try {
        const a = (await (await fetch(`https://api3.geo.admin.ch/rest/services/api/SearchServer?type=locations&origins=address&sr=2056&limit=1&searchText=${encodeURIComponent(adr)}`)).json()).results?.[0]?.attrs;
        if (a) { k.geo_lat = a.lat; k.geo_lon = a.lon; await admin.from('kunde').update({ geo_lat: a.lat, geo_lon: a.lon, geo_stand: new Date().toISOString() }).eq('id', k.id); }
      } catch (_) { /* ohne Koordinaten weiter */ }
      return k;
    };
    const ziel = (k: any, info: string, lat?: number, lon?: number) => ({ kunde_id: k.id, name: [kName(k), ortOhnePlz(k.ort)].filter(Boolean).join(', '),
      adresse: [k.strasse, [k.plz, ortOhnePlz(k.ort)].filter(Boolean).join(' ')].filter(Boolean).join(', '), info,
      distanz: lat && lon && k.geo_lat && k.geo_lon ? Math.round(distanz(lat, lon, k.geo_lat, k.geo_lon)) : null });

    if (body.aktion === 'ziele') {
      const lat = Number(body.lat) || 0, lon = Number(body.lon) || 0, heute = tagZh(new Date());
      const { data: pers } = await admin.from('planer_person').select('id').eq('benutzer_id', user.id);
      const ids = (pers || []).map((p: any) => p.id);
      let einsaetze: any[] = [];
      if (ids.length) {
        const von = new Date(Date.now() - 36 * 3600e3).toISOString(), bis = new Date(Date.now() + 36 * 3600e3).toISOString();
        const { data } = await admin.from('planer_einsatz').select('id,kunde_id,titel,beginn,ende,person_id,mit_person_id')
          .not('kunde_id', 'is', null).lt('beginn', bis).gt('ende', von).or(`person_id.in.(${ids.join(',')}),mit_person_id.in.(${ids.join(',')})`);
        einsaetze = (data || []).filter((e: any) => tagZh(new Date(e.beginn)) <= heute && tagZh(new Date(new Date(e.ende).getTime() - 1)) >= heute);
      }
      const kids = [...new Set(einsaetze.map(e => e.kunde_id))];
      const { data: ks } = kids.length ? await admin.from('kunde').select(KFELDER).in('id', kids) : { data: [] };
      const liste = await Promise.all((ks || []).map(async (k: any) => { await koordinaten(k); const e = einsaetze.find(x => x.kunde_id === k.id);
        return ziel(k, 'Einsatz heute' + (e?.titel ? ' · ' + e.titel : ''), lat, lon); }));
      // Zweiter Weg: Adressen der Gebäude um den Standort (Gebäuderegister des Bundes) → Kunde mit dieser Adresse
      if (lat && lon) {
        try {
          const d = 0.002, u = `https://api3.geo.admin.ch/rest/services/api/MapServer/identify?geometry=${lon},${lat}&geometryType=esriGeometryPoint&sr=4326&layers=all:ch.bfs.gebaeude_wohnungs_register&tolerance=250&returnGeometry=true&geometryFormat=geojson&imageDisplay=1000,1000,96&mapExtent=${lon - d},${lat - d},${lon + d},${lat + d}&lang=de`;
          const geb = ((await (await fetch(u)).json()).results || []).map((r: any) => ({ str: (r.properties.strname || [])[0], nr: r.properties.deinr, plz: r.properties.dplz4,
            m: Math.round(distanz(lat, lon, r.geometry.coordinates[1], r.geometry.coordinates[0])) })).filter((g: any) => g.str && g.nr && g.m <= 150).sort((a: any, b: any) => a.m - b.m).slice(0, 12);
          for (const g of geb) {
            const { data: tr } = await admin.from('kunde').select(KFELDER).ilike('strasse', `${g.str} ${g.nr}%`).or(`plz.eq.${g.plz},ort.ilike.${g.plz}%`).limit(3);
            for (const k of tr || []) if (!liste.some(z => z.kunde_id === k.id)) liste.push({ ...ziel(k, 'Adresse in der Nähe'), distanz: g.m });
          }
        } catch (_) { /* Gebäuderegister nicht erreichbar: nur Einsätze */ }
      }
      liste.sort((a, b) => (a.distanz ?? 9e9) - (b.distanz ?? 9e9));
      return json({ ziele: liste, naechste: liste[0] && liste[0].distanz != null && liste[0].distanz <= 150 ? liste[0].kunde_id : null });
    }

    if (body.aktion === 'suche') {
      // jedes Wort muss irgendwo vorkommen (Name, Ort, Strasse); gesucht wird mit dem längsten Wort, gefiltert mit allen
      const woerter = String(body.q || '').replace(/[,()%*.]/g, ' ').toLowerCase().split(/\s+/).filter(w => w.length >= 2);
      if (!woerter.length) return json({ ziele: [] });
      const w = [...woerter].sort((a, b) => b.length - a.length)[0];
      const { data } = await admin.from('kunde').select(KFELDER).or(`name.ilike.%${w}%,nachname.ilike.%${w}%,vorname.ilike.%${w}%,firma.ilike.%${w}%,ort.ilike.%${w}%,strasse.ilike.%${w}%`).limit(200);
      const treffer = (data || []).filter((k: any) => { const t = [k.name, k.vorname, k.nachname, k.firma, k.ort, k.strasse, k.plz].join(' ').toLowerCase(); return woerter.every(x => t.includes(x)); }).slice(0, 12);
      return json({ ziele: treffer.map((k: any) => ziel(k, '')) });
    }

    if (body.aktion === 'erfasst') {
      const rows = (body.dateien || []).filter((d: any) => d && d.id).map((d: any) => ({ benutzer_id: user.id, kunde_id: body.kunde_id, drive_datei_id: d.id, dateiname: d.name,
        ordner_id: body.ordner_id, lat: Number(body.lat) || null, lon: Number(body.lon) || null }));
      if (rows.length) await admin.from('foto_ablage').insert(rows);
      return json({ ok: true });
    }

    if (body.aktion === 'hochladen' || body.aktion === 'vorbereiten') {
      const { data: k } = await admin.from('kunde').select(KFELDER + ',kundennummer').eq('id', body.kunde_id).maybeSingle();
      if (!k) return json({ error: 'Kunde nicht gefunden.' }, 404);
      // Zugang des Firmenkontos
      const secret = Deno.env.get('GOOGLE_CLIENT_SECRET'); if (!secret) return json({ error: 'GOOGLE_CLIENT_SECRET fehlt.' }, 500);
      const { data: fb } = await admin.from('benutzer').select('id').ilike('email', FIRMENKONTO).maybeSingle();
      const { data: gv } = fb ? await admin.from('google_verbindung').select('refresh_token').eq('benutzer_id', fb.id).maybeSingle() : { data: null };
      if (!gv) return json({ error: 'Das Firmenkonto ist nicht mit Google verbunden (Büro: Doku-Tools › Google verbinden).' }, 500);
      const tr = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ refresh_token: gv.refresh_token, client_id: CLIENT_ID, client_secret: secret, grant_type: 'refresh_token' }) });
      const tok = await tr.json(); if (!tr.ok) return json({ error: 'Google-Zugang: ' + (tok.error_description || tok.error) }, 500);
      const gapi = async (pfad: string, opt: any = {}) => { const r = await fetch((pfad.startsWith('http') ? '' : 'https://www.googleapis.com/drive/v3/') + pfad,
        { ...opt, headers: { Authorization: 'Bearer ' + tok.access_token, ...(opt.headers || {}) } }); const d = await r.json().catch(() => ({}));
        if (!r.ok) throw new Error('Google Drive: ' + (d?.error?.message || r.status)); return d; };
      const kinder = async (id: string) => { const out: any[] = []; let t = '';
        do { const p = new URLSearchParams({ q: `'${id}' in parents and trashed=false and mimeType='${ORDNER}'`, corpora: 'drive', driveId: ROOT, includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: 'nextPageToken,files(id,name)', pageSize: '1000' });
          if (t) p.set('pageToken', t); const d = await gapi('files?' + p); out.push(...(d.files || [])); t = d.nextPageToken || ''; } while (t);
        return out; };
      const neu = (name: string, parent: string) => gapi('files?supportsAllDrives=true&fields=id,name', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name, mimeType: ORDNER, parents: [parent] }) });
      const kopieren = async (q: string, parent: string, name: string): Promise<any> => { const n = await neu(name, parent); for (const c of await kinder(q)) await kopieren(c.id, n.id, c.name); return n; };
      // Kundenordner des aktuellen Jahres (fehlt er: aus der Vorlage anlegen und verknüpfen, wie kg-kundenordner.js)
      const jahr = new Date().getFullYear();
      let { data: ko } = await admin.from('kunde_ordner').select('*').eq('kunde_id', k.id).eq('jahr', jahr).limit(1).maybeSingle();
      if (!ko) {
        const jl = await kinder(ROOT), jo = jl.find(f => f.name === String(jahr)) || await neu(String(jahr), ROOT);
        const da = new Set((await kinder(jo.id)).map(f => f.name.toLowerCase()));
        const basis = [k.nachname || k.firma || k.name, ortOhnePlz(k.ort)].filter(Boolean).join(' ').trim() || 'Kunde';
        let name = basis; if (da.has(name.toLowerCase())) name = `${basis} (${String(k.strasse || k.kundennummer || 'neu').replace(/\s*\d.*$/, '') || 'neu'})`;
        let n = 2; while (da.has(name.toLowerCase())) name = `${basis} (${n++})`;
        const vl = await kinder(VORLAGE), muster = vl.find(f => /^zzzz/i.test(f.name));
        const o = await kopieren(muster ? muster.id : VORLAGE, jo.id, name);
        const { data: neuK } = await admin.from('kunde_ordner').insert({ kunde_id: k.id, jahr, drive_id: o.id, name, erstellt_von: user.id }).select().single();
        ko = neuK;
      }
      const unter = await kinder(ko.drive_id);
      const u = unter.find(f => /^22\b/.test(f.name)) || unter.find(f => /bauablauf/i.test(f.name)) || await neu('22-Fotos-Bauablauf und Schluss', ko.drive_id);
      if (body.aktion === 'vorbereiten') {
        const origin = String(body.origin || '');
        const sitzungen = await Promise.all((body.dateien || []).map(async (f: any) => {
          const r = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true&fields=id,name', { method: 'POST',
            headers: { Authorization: 'Bearer ' + tok.access_token, 'Content-Type': 'application/json; charset=UTF-8', 'X-Upload-Content-Type': String(f.typ || 'image/jpeg'),
              ...(f.groesse ? { 'X-Upload-Content-Length': String(f.groesse) } : {}), ...(origin ? { Origin: origin } : {}) },
            body: JSON.stringify({ name: String(f.name || 'Foto.jpg'), parents: [u.id] }) });
          if (!r.ok) throw new Error('Google Drive: ' + ((await r.json().catch(() => ({})))?.error?.message || r.status));
          return r.headers.get('Location');
        }));
        return json({ sitzungen, ordner_id: u.id, ordner: `${ko.jahr} › ${u.name}`, kunde: kName(k) });
      }
      // Datei hochladen
      const bytes = Uint8Array.from(atob(String(body.daten || '')), c => c.charCodeAt(0));
      if (!bytes.length) return json({ error: 'Kein Bild erhalten.' }, 400);
      const form = new FormData();
      form.append('metadata', new Blob([JSON.stringify({ name: String(body.dateiname || 'Foto.jpg'), parents: [u.id] })], { type: 'application/json' }));
      form.append('file', new Blob([bytes], { type: String(body.typ || 'image/jpeg') }));
      const d = await gapi('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name', { method: 'POST', body: form });
      await admin.from('foto_ablage').insert({ benutzer_id: user.id, kunde_id: k.id, drive_datei_id: d.id, dateiname: d.name, ordner_id: u.id, lat: Number(body.lat) || null, lon: Number(body.lon) || null });
      return json({ ok: true, datei: d.name, ordner: `${ko.jahr} › ${u.name}`, kunde: kName(k) });
    }
    return json({ error: 'Unbekannte Aktion.' }, 400);
  } catch (e) {
    return json({ error: String((e as any)?.message || e) }, 500);
  }
});
