/* kg-kundenordner.js – Kundenordner im Google Drive (geteilte Ablage «01_Kundendaten / Projekte»)
   Einbinden nach supabase-js und kg-doku.js:  <script src="/kg-doku.js?v=1"></script><script src="/kg-kundenordner.js?v=1"></script>
   - Verknüpfung über die Ordner-ID pro Kunde und Jahr (Tabelle kunde_ordner), Namen spielen keine Rolle
   - neuer Jahresordner = Ordnerstruktur eines vorbereiteten Kundenordners aus «Vorlage 01-99» (nur Ordner, keine Dateien)
   - Google-Zugang wie in den Doku-Tools (KGD.googleToken / KGD.googleVerbinden, Refresh-Token serverseitig)
   KKO.init(sb) einmal aufrufen. */
(function(){
  const ROOT = '0AEZm9ALFx3sgUk9PVA', VORLAGE = '12hH-QP2_RZ559nmmxG_ZsKCrazUh6pon', ORDNER = 'application/vnd.google-apps.folder';
  const ortOhnePlz = o => String(o || '').replace(/^\d{4}\s*/, '').trim();
  const kinder = async (id, nurOrdner) => { const out = []; let token = '';
    do { const p = new URLSearchParams({ q: `'${id}' in parents and trashed=false${nurOrdner ? ` and mimeType='${ORDNER}'` : ''}`, corpora: 'drive', driveId: ROOT,
        includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: 'nextPageToken,files(id,name,mimeType,modifiedTime,webViewLink,iconLink)', pageSize: '200', orderBy: 'folder,name' });
      if(token) p.set('pageToken', token);
      const d = await KGD.gapi('files?' + p); out.push(...(d.files || [])); token = d.nextPageToken || ''; } while(token);
    return out; };
  const ordnerNeu = (name, parent) => KGD.gapi('files?supportsAllDrives=true&fields=id,name,webViewLink', { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, mimeType: ORDNER, parents: [parent] }) });
  let vorlageId = null;

  window.KKO = {
    sb: null,
    init(sb){ KKO.sb = sb; if(window.KGD) KGD.sb = sb; },
    link: id => 'https://drive.google.com/drive/folders/' + id,
    // Google: verbunden? (ohne Popup) / verbinden (muss aus einem Klick kommen)
    async verbunden(){ try { return !!(await KGD.googleToken()); } catch(e){ return false; } },
    async verbinden(){ await KGD.gsiLaden(); return KGD.googleVerbinden(); },
    vorladen(){ KGD.gsiLaden().catch(() => {}); },
    // verknüpfte Ordner eines Kunden (neueste zuerst, Stammordner oben)
    async liste(kundeId){ const { data, error } = await KKO.sb.from('kunde_ordner').select('*').eq('kunde_id', kundeId).order('jahr', { ascending: false, nullsFirst: true }); if(error) throw error; return data || []; },
    async verknuepfen(kundeId, o){ const { data, error } = await KKO.sb.from('kunde_ordner').upsert({ kunde_id: kundeId, jahr: o.jahr ? +o.jahr : null, drive_id: o.id, name: o.name }, { onConflict: 'kunde_id,drive_id' }).select().single(); if(error) throw error; return data; },
    async loesen(id){ const { error } = await KKO.sb.from('kunde_ordner').delete().eq('id', id); if(error) throw error; },
    // Vorschläge aus den Jahresordnern (Name, Ort, Strasse) – nur Vorschläge, bestätigen muss man selbst
    // Ortsname im Kundennamen («Aarekies Brienz AG») zählt nicht als Name; nur Ordner, bei denen der Name passt
    async vorschlaege(k){ const ort = ortOhnePlz(k.ort).toLowerCase(), name = String(k.nachname || k.firma || k.name || '').split(/\s+/).filter(w => !ort || w.toLowerCase() !== ort).join(' ');
      return (await KGD.ordnerVorschlag({ kunde_name: name, ort: k.ort, strasse: k.strasse })).filter(v => v.gruende.includes('Name passt')); },
    async ausLink(text){ const o = await KGD.ordnerAusLink(text); const f = await KGD.gapi(`files/${o.id}?supportsAllDrives=true&fields=id,name,parents`);
      let jahr = null; if(f.parents && f.parents[0]){ try { const p = await KGD.gapi(`files/${f.parents[0]}?supportsAllDrives=true&fields=name`); if(/^\d{4}$/.test(p.name)) jahr = +p.name; } catch(e){} }
      return { id: f.id, name: f.name, jahr }; },
    // Jahresordner «2026» unter der Ablage (fehlt er: anlegen)
    async jahresOrdner(jahr){ const l = await kinder(ROOT, true); const j = l.find(f => f.name === String(jahr)); return j || ordnerNeu(String(jahr), ROOT); },
    // Muster = erster vorbereitete Kundenordner (nur die Ordnerstruktur wird übernommen, keine Dateien) in der Vorlage («ZZZZZ-…»), sonst die Vorlage selbst
    async vorlage(){ if(vorlageId) return vorlageId; const l = await kinder(VORLAGE, true); const z = l.find(f => /^zzzz/i.test(f.name)); return (vorlageId = z ? z.id : VORLAGE); },
    async kopieren(quelleId, zielParent, name){
      const neu = await ordnerNeu(name, zielParent);
      for(const c of await kinder(quelleId, true)) await KKO.kopieren(c.id, neu.id, c.name); // nur Unterordner, keine Dateien (Entscheid 2026-11-05)
      return neu;
    },
    // Kundenordner für ein Jahr anlegen (aus der Vorlage) und verknüpfen. Name «Meier Thun», gibt es ihn schon: «Meier Thun (Seestrasse)»
    async anlegen(k, jahr = new Date().getFullYear()){
      const jo = await KKO.jahresOrdner(jahr), da = new Set((await kinder(jo.id, true)).map(f => f.name.toLowerCase()));
      const basis = [k.nachname || k.firma || k.name, ortOhnePlz(k.ort)].filter(Boolean).join(' ').trim() || 'Kunde';
      let name = basis; if(da.has(name.toLowerCase())) name = `${basis} (${String(k.strasse || k.kundennummer || 'neu').replace(/\s*\d.*$/, '') || 'neu'})`;
      let n = 2; while(da.has(name.toLowerCase())) name = `${basis} (${n++})`;
      const neu = await KKO.kopieren(await KKO.vorlage(), jo.id, name);
      return KKO.verknuepfen(k.id, { id: neu.id, name, jahr });
    },
    // Ordner des aktuellen Jahres (fehlt er: aus der Vorlage anlegen)
    async aktuell(k){ const j = new Date().getFullYear(), l = await KKO.liste(k.id); return l.find(o => o.jahr === j) || KKO.anlegen(k, j); },
    // Dateien hochladen: Fotos in «20-Fotos Situation», alles andere in «06-Notizen» (fehlt der Unterordner: in den Kundenordner)
    async hochladen(k, files){
      const o = await KKO.aktuell(k), unter = await kinder(o.drive_id, true), erg = [];
      for(const f of files){
        const u = unter.find(x => (/^image\//.test(f.type) ? /^20\b/ : /^06\b/).test(x.name)), ziel = u ? u.id : o.drive_id;
        const form = new FormData();
        form.append('metadata', new Blob([JSON.stringify({ name: f.name, parents: [ziel] })], { type: 'application/json' }));
        form.append('file', f);
        erg.push(await KGD.gapi('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,webViewLink', { method: 'POST', body: form }));
      }
      return { ordner: o, dateien: erg };
    },
    async dateien(ordnerId){ return kinder(ordnerId, false); },
    ROOT, async unterordner(id){ return kinder(id, true); }
  };
})();
