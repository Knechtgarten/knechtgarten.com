/* ============================================================================
   kg-kunde.js – Kunde ändern, Objekte, Verknüpfungen (Kontakte + Offertentool)

   KGKunde.setze(sb)                         Supabase-Client der Seite übergeben
   KGKunde.speichern(kundeAlt, neu)          Kunde speichern; fragt bei echter Adress-/Namensänderung,
                                             welche Offerten die neue Adresse bekommen (und ob Umzug),
                                             schreibt Easybill-Kunden mit. -> { ok, text } | null (abgebrochen)
   KGKunde.fenster(kundeId, { offerteId, onSaved })   kleines Fenster fürs Offertentool:
                                             Name/Adresse ändern + Arbeitsort (Objekt) der Offerte
   KGKunde.ladeAlle()                        { objekte: Map(kunde_id -> [..]), bez: Map(kunde_id -> [..]) }
   KGKunde.objekteVerwalten(el, kundeId, nachher)       Liste mit + / Bearbeiten / Löschen
   KGKunde.verknuepfungenVerwalten(el, kundeId, nachher)
   KGKunde.bezText(b, kundeId) -> { art: 'Vorbesitzer', andere: kunde_id }

   Regeln (Entscheid 2026-11-19):
   - Gefragt wird nur bei echter Änderung: PLZ anders, Ort/Strasse um mehr als einen Buchstaben anders,
     andere Hausnummer -> Umzug-Frage + Offerten-Liste. Name um mehr als einen Buchstaben anders -> nur Offerten-Liste.
   - Vorausgewählt: Korrektur = alle Offerten, sonst nur offene.
   ============================================================================ */
(function(){
  const K = window.KGKunde = {};
  let sb = null;
  K.setze = c => { sb = c; };
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const ic = (n, s) => (window.KG && KG.icon) ? KG.icon(n, s || 14) : '';
  const norm = s => String(s ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
  function lev(a, b){
    if(a === b) return 0; if(!a.length) return b.length; if(!b.length) return a.length;
    let v = Array.from({ length: b.length + 1 }, (_, i) => i);
    for(let i = 1; i <= a.length; i++){ const w = [i];
      for(let j = 1; j <= b.length; j++) w[j] = Math.min(v[j] + 1, w[j - 1] + 1, v[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      v = w; }
    return v[b.length];
  }
  const hausnr = s => (String(s || '').match(/\d+\s*[a-z]?\b/i) || [''])[0].replace(/\s/g, '').toLowerCase();
  const ohneNr = s => norm(s).replace(/\d+\s*[a-z]?\b/gi, '').trim();
  const nameVon = k => norm([k.firma, k.vorname, k.nachname].filter(Boolean).join(' ') || k.name);
  const adrText = k => [k.strasse, [k.plz, k.ort].filter(Boolean).join(' ')].filter(Boolean).join(', ');
  K.adrText = adrText;

  // Was hat sich wirklich geändert?
  K.aenderung = (a, n) => {
    const hatteAdresse = !!(norm(a.strasse) || norm(a.plz) || norm(a.ort));
    const adresse = hatteAdresse && (norm(a.plz) !== norm(n.plz) || lev(norm(a.ort), norm(n.ort)) > 1
      || lev(ohneNr(a.strasse), ohneNr(n.strasse)) > 1 || hausnr(a.strasse) !== hausnr(n.strasse));
    const name = lev(nameVon(a), nameVon(n)) > 1;
    return { adresse, name };
  };

  // ------------------------------------------------------------------ Stil (einmal)
  function stil(){
    if(document.getElementById('kgk-stil')) return;
    const st = document.createElement('style'); st.id = 'kgk-stil';
    st.textContent = `
.kgk-ovl{position:fixed;inset:0;background:rgba(50,62,78,.35);z-index:3000;display:flex;align-items:flex-start;justify-content:center;padding:6vh 16px;overflow:auto;}
.kgk-box{background:#fff;border-radius:12px;box-shadow:0 12px 40px rgba(50,62,78,.25);width:100%;max-width:620px;padding:20px 22px;color:#323E4E;font-size:13px;box-sizing:border-box;}
.kgk-box h3{margin:0 0 4px;font-size:15px;font-weight:700;}
.kgk-box .kgk-sub{color:#8B9097;font-size:12px;margin-bottom:12px;}
.kgk-box h4{margin:16px 0 6px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:#8B9097;}
.kgk-wahl{display:flex;flex-direction:column;gap:6px;}
.kgk-wahl label{display:flex;gap:10px;align-items:flex-start;border:1px solid #DCE1E6;border-radius:8px;padding:8px 10px;cursor:pointer;line-height:1.35;}
.kgk-wahl label:hover{border-color:#8B9097;} .kgk-wahl label.an{border-color:#323E4E;background:#F5F7F9;}
.kgk-wahl label small{display:block;color:#8B9097;font-size:11.5px;}
.kgk-wahl input{margin-top:2px;accent-color:#323E4E;}
.kgk-of{border:1px solid #DCE1E6;border-radius:8px;max-height:260px;overflow:auto;}
.kgk-of label{display:grid;grid-template-columns:18px 58px minmax(0,1fr) 74px 82px;gap:8px;align-items:center;padding:6px 10px;border-bottom:1px solid #EEF1F4;cursor:pointer;font-size:12.5px;}
.kgk-of label:last-child{border-bottom:0;} .kgk-of input{accent-color:#323E4E;margin:0;}
.kgk-of .t{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;} .kgk-of .d,.kgk-of .n{color:#8B9097;font-variant-numeric:tabular-nums;}
.kgk-st{font-size:10.5px;font-weight:600;border-radius:10px;padding:1px 8px;text-align:center;background:#EEF1F4;color:#4C5C70;}
.kgk-st.zugesagt,.kgk-st.bestaetigt{background:#D1DB5F;color:#323E4E;} .kgk-st.abgelehnt{background:#E8C9C5;color:#7A3A33;}
.kgk-alle{font-size:12px;color:#323E4E;font-weight:600;background:none;border:0;padding:0;cursor:pointer;text-decoration:underline;margin:0 0 6px;}
.kgk-hin{font-size:11.5px;color:#8B9097;margin-top:8px;line-height:1.4;}
.kgk-btns{display:flex;justify-content:flex-end;gap:8px;margin-top:18px;align-items:center;}
.kgk-btns .kgk-links{margin-right:auto;}
.kgk-b{height:34px;padding:0 16px;border-radius:8px;font:inherit;font-weight:600;font-size:13px;cursor:pointer;border:1px solid #323E4E;background:#323E4E;color:#fff;}
.kgk-b:disabled{opacity:.45;cursor:default;} .kgk-b.g{background:#fff;color:#323E4E;border-color:#D5DBE1;}
.kgk-b.l{border:0;background:none;color:#323E4E;padding:0 4px;text-decoration:underline;font-weight:500;}
.kgk-row{display:flex;gap:8px;margin-bottom:8px;} .kgk-fld{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px;}
.kgk-fld label{font-size:11px;color:#8B9097;}
.kgk-fld input,.kgk-fld select{height:32px;border:1px solid #D5DBE1;border-radius:8px;padding:0 9px;font:inherit;font-size:13px;color:#323E4E;background:#fff;box-sizing:border-box;width:100%;}
.kgk-fld input:focus,.kgk-fld select:focus{outline:none;border-color:#323E4E;}
.kgk-err{color:#B4655F;font-size:12px;margin-top:8px;min-height:1px;}
.kgk-fix{background:#F5F7F9;border:1px solid #DCE1E6;border-radius:8px;padding:8px 10px;font-size:12.5px;display:flex;gap:10px;align-items:center;justify-content:space-between;margin-bottom:10px;}
.kgk-liste{display:flex;flex-direction:column;}
.kgk-z{display:flex;align-items:center;gap:8px;padding:5px 0;border-bottom:1px solid #EEF1F4;font-size:12.5px;}
.kgk-z:last-child{border-bottom:0;} .kgk-z .t{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.kgk-z .t b{font-weight:600;} .kgk-z .t span{color:#8B9097;} .kgk-z .kg-ibtn{flex:none;}
.kgk-z a{color:#323E4E;}
.kgk-leer{color:#8B9097;font-size:12px;padding:4px 0;}
.kgk-plus{font-size:12.5px;color:#323E4E;font-weight:600;background:none;border:0;padding:6px 0 0;cursor:pointer;display:inline-flex;align-items:center;gap:4px;}
.kgk-form{border:1px solid #DCE1E6;border-radius:8px;padding:10px;margin-top:6px;background:#FBFCFD;}
.kgk-treffer{border:1px solid #DCE1E6;border-radius:8px;max-height:180px;overflow:auto;margin-top:4px;background:#fff;}
.kgk-treffer button{display:flex;width:100%;gap:8px;justify-content:space-between;border:0;border-bottom:1px solid #EEF1F4;background:#fff;padding:6px 9px;font:inherit;font-size:12.5px;color:#323E4E;cursor:pointer;text-align:left;}
.kgk-treffer button:hover,.kgk-treffer button.an{background:#F5F7F9;} .kgk-treffer button span{color:#8B9097;}
.kgk-chk{display:flex;gap:8px;align-items:center;font-size:12.5px;margin-top:8px;} .kgk-chk input{accent-color:#323E4E;}
.kgk-inaktiv{font-size:10.5px;color:#8B9097;border:1px solid #DCE1E6;border-radius:10px;padding:0 6px;margin-left:4px;}
`;
    document.head.appendChild(st);
  }
  function overlay(html){
    stil();
    const o = document.createElement('div'); o.className = 'kgk-ovl';
    o.innerHTML = `<div class="kgk-box" role="dialog" aria-modal="true">${html}</div>`;
    document.body.appendChild(o);
    return o;
  }

  const STATUS = { offen: 'Offen', bestaetigt: 'Bestätigt', zugesagt: 'Zugesagt', abgelehnt: 'Abgelehnt' };
  const datum = d => d ? new Date(d).toLocaleDateString('de-CH', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '';
  const istOffen = o => !o.status || o.status === 'offen';

  // ------------------------------------------------------------------ Frage-Fenster
  function frageFenster(alt, neu, aend, offerten){
    return new Promise(res => {
      const wahl = aend.adresse ? `
        <h4>Was ist mit der bisherigen Adresse?</h4>
        <div class="kgk-sub" style="margin:0 0 8px">${esc(adrText(alt))}</div>
        <div class="kgk-wahl">
          <label><input type="radio" name="kgkart" value="korrektur"><span><b>Korrektur</b><small>Falsch geschrieben oder Angabe ergänzt – es ist dieselbe Adresse.</small></span></label>
          <label><input type="radio" name="kgkart" value="umzug_objekt"><span><b>Umzug, bisherige Adresse bleibt als Objekt</b><small>z. B. vermietet und wir pflegen weiter: wird ein Objekt mit den bisherigen Offerten.</small></span></label>
          <label><input type="radio" name="kgkart" value="umzug_weg"><span><b>Umzug, bisherige Adresse aufgeben</b><small>Bleibt nur im Verlauf und bei den Offerten ohne Häkchen.</small></span></label>
        </div>` : '';
      const ofHtml = offerten.length ? `
        <h4>Welche Offerten bekommen ${aend.adresse ? 'die neue Adresse' : 'den neuen Namen'}?</h4>
        <button type="button" class="kgk-alle" data-kgk-alle>Alle</button>
        <div class="kgk-of">${offerten.map(o => `<label><input type="checkbox" value="${o.id}"><span class="n">${esc(o.offertnummer || '')}</span><span class="t">${esc(o.titel || 'Offerte')}</span><span class="d">${datum(o.datum)}</span><span class="kgk-st ${esc(o.status || 'offen')}">${STATUS[o.status] || 'Offen'}</span></label>`).join('')}</div>
        <div class="kgk-hin">Ohne Häkchen behält die Offerte die bisherige ${aend.adresse ? 'Adresse' : 'Schreibweise'}.${neu._easybill ? ' Der Easybill-Kunde wird mitgeändert; Easybill-Angebote, die noch Entwurf sind, ebenfalls. Abgeschlossene Easybill-Dokumente bleiben, wie sie sind.' : ''}</div>` : '';
      const o = overlay(`<h3>${aend.adresse ? 'Adresse geändert' : 'Name geändert'}</h3>
        <div class="kgk-sub">${esc(nameVon(alt) === nameVon(neu) ? (neu.name || '') : (alt.name || '') + ' → ' + (neu.name || ''))}${aend.adresse ? ' · neu: ' + esc(adrText(neu)) : ''}</div>
        ${wahl}${ofHtml}
        <div class="kgk-err"></div>
        <div class="kgk-btns"><button type="button" class="kgk-b g" data-kgk-ab>Abbrechen</button><button type="button" class="kgk-b" data-kgk-ok>Speichern</button></div>`);
      const boxes = [...o.querySelectorAll('.kgk-of input')];
      const vorwahl = art => boxes.forEach(b => { const of = offerten.find(x => x.id === b.value); b.checked = art === 'korrektur' ? true : istOffen(of); });
      vorwahl(aend.adresse ? null : 'name');
      o.querySelectorAll('input[name=kgkart]').forEach(r => r.addEventListener('change', () => {
        o.querySelectorAll('.kgk-wahl label').forEach(l => l.classList.toggle('an', l.querySelector('input').checked)); vorwahl(r.value); }));
      o.querySelector('[data-kgk-alle]')?.addEventListener('click', () => { const alle = boxes.every(b => b.checked); boxes.forEach(b => b.checked = !alle); });
      const zu = v => { o.remove(); res(v); };
      o.querySelector('[data-kgk-ab]').onclick = () => zu(null);
      o.addEventListener('keydown', e => { if(e.key === 'Escape') zu(null); });
      o.querySelector('[data-kgk-ok]').onclick = () => {
        const art = aend.adresse ? o.querySelector('input[name=kgkart]:checked')?.value : 'name';
        if(!art){ o.querySelector('.kgk-err').textContent = 'Bitte wählen: Korrektur oder Umzug.'; return; }
        zu({ art, offerten: boxes.filter(b => b.checked).map(b => b.value) });
      };
    });
  }

  // ------------------------------------------------------------------ Speichern
  const FELDER = ['name', 'kundennummer', 'firma', 'anrede', 'vorname', 'nachname', 'zusatz1', 'zusatz2', 'strasse', 'plz', 'ort', 'land', 'kontaktdaten'];
  K.speichern = async (alt, neu) => {
    const aend = K.aenderung(alt, neu);
    let art = null, ids = [], offerten = [];
    if(aend.adresse || aend.name){
      const { data, error } = await sb.from('offerte').select('id,offertnummer,titel,datum,status,objekt_id,adresse_fix,easybill_document_id')
        .eq('kunde_id', alt.id).is('objekt_id', null).order('datum', { ascending: false }).range(0, 499);
      if(error) return { ok: false, text: error.message };
      offerten = data || [];
      if(aend.adresse || offerten.length){
        const r = await frageFenster(alt, { ...neu, _easybill: !!alt.easybill_id }, aend, offerten);
        if(!r) return null;
        art = r.art; ids = r.offerten;
      } else art = 'name';
    }
    const p = {}; FELDER.forEach(f => { if(f in neu) p[f] = neu[f]; });
    const { data: erg, error } = await sb.rpc('kunde_adresse_aendern', { p_kunde: alt.id, p_neu: p, p_art: art, p_offerten: ids });
    if(error) return { ok: false, text: error.message };
    const teile = [];
    if(erg?.objekt_id) teile.push('bisherige Adresse ist jetzt ein Objekt');
    if(erg?.eingefroren) teile.push(`${erg.eingefroren} Offerte${erg.eingefroren === 1 ? '' : 'n'} ${erg.objekt_id ? 'beim Objekt' : 'behalten die bisherige Adresse'}`);
    // Easybill-Kunde mitschreiben (sonst überschreibt ihn der Nachtabgleich wieder)
    if(alt.easybill_id){
      const doks = offerten.filter(o => ids.includes(o.id) && o.easybill_document_id).map(o => o.easybill_document_id);
      const { data, error: fe } = await sb.functions.invoke('easybill-kunde-aendern', { body: { kunde_id: alt.id, dokumente: doks } });
      let msg = data?.error; if(fe && !msg){ try { msg = (await fe.context?.json())?.error; } catch(e){} msg = msg || fe.message; }
      if(msg) return { ok: true, warnung: true, text: 'Gespeichert, aber Easybill hat die Änderung nicht übernommen: ' + msg + ' – bitte in Easybill nachtragen, sonst kommt nachts die alte Adresse zurück.' };
      const akt = (data?.dokumente || []).filter(d => d.ergebnis === 'aktualisiert').length;
      teile.push('in Easybill geändert' + (akt ? ` (${akt} Angebots-Entwurf${akt === 1 ? '' : 'e'})` : ''));
    }
    return { ok: true, text: 'Gespeichert' + (teile.length ? ': ' + teile.join(', ') : '') + '.' };
  };

  // ------------------------------------------------------------------ Objekte + Verknüpfungen laden
  K.ladeAlle = async () => {
    const [o, b] = await Promise.all([
      sb.from('kunde_objekt').select('*').order('reihenfolge').order('erstellt_am').range(0, 9999),
      sb.from('kunde_beziehung').select('*, von:kunde_von(id,name,ort,inaktiv), zu:kunde_zu(id,name,ort,inaktiv)').range(0, 9999)]);
    const objekte = new Map(), bez = new Map();
    (o.data || []).forEach(x => { if(!objekte.has(x.kunde_id)) objekte.set(x.kunde_id, []); objekte.get(x.kunde_id).push(x); });
    (b.data || []).forEach(x => [x.kunde_von, x.kunde_zu].forEach(id => { if(!bez.has(id)) bez.set(id, []); bez.get(id).push(x); }));
    return { objekte, bez };
  };

  // Verknüpfungs-Arten aus Sicht des Kunden, bei dem man sie anlegt (von = andere Person, zu = dieser Kunde, umgekehrt = ich bin von)
  const ARTEN = [
    { k: 'vorbesitzer', n: 'Vorbesitzer', art: 'nachfolger', ich: 'zu' },
    { k: 'nachfolger', n: 'Nachfolger', art: 'nachfolger', ich: 'von' },
    { k: 'gleich', n: 'Gleiche Person / Inhaber', art: 'gleich', ich: 'von' },
    { k: 'verwaltung', n: 'Verwaltung', art: 'verwaltung', ich: 'zu' },
    { k: 'verwaltet', n: 'Verwaltet', art: 'verwaltung', ich: 'von' },
    { k: 'mieter', n: 'Mieter', art: 'mieter', ich: 'zu' },
    { k: 'mieterbei', n: 'Mieter bei', art: 'mieter', ich: 'von' },
    { k: 'architekt', n: 'Architekt / Planer', art: 'architekt', ich: 'zu' },
    { k: 'andere', n: 'Andere Verknüpfung', art: 'andere', ich: 'von' },
  ];
  K.bezText = (b, kundeId) => {
    const ichVon = b.kunde_von === kundeId;
    const a = ARTEN.find(x => x.art === b.art && (x.art === 'gleich' || x.art === 'andere' || (x.ich === 'von') === ichVon));
    return { art: b.art === 'andere' ? 'Verknüpft' : a ? a.n : b.art, andere: ichVon ? b.zu : b.von, andereId: ichVon ? b.kunde_zu : b.kunde_von };
  };

  // ------------------------------------------------------------------ Objekte verwalten
  K.objekteVerwalten = async (el, kundeId, nachher) => {
    stil();
    const zeichne = async () => {
      const { data } = await sb.from('kunde_objekt').select('*').eq('kunde_id', kundeId).order('reihenfolge').order('erstellt_am');
      const liste = data || [];
      el.innerHTML = `<div class="kgk-liste">${liste.map(o => `<div class="kgk-z" data-id="${o.id}"><span class="t"><b>${esc(o.name || 'Objekt')}</b> <span>${esc(adrText(o))}</span></span>
          <button type="button" class="kg-ibtn" data-oed="${o.id}" title="Bearbeiten" aria-label="Bearbeiten">${ic('edit', 13)}</button>
          <button type="button" class="kg-ibtn danger" data-oweg="${o.id}" title="Löschen" aria-label="Löschen">${ic('trash', 13)}</button></div>`).join('')
        || '<div class="kgk-leer">Kein Objekt – gearbeitet wird an der Kundenadresse.</div>'}</div>
        <button type="button" class="kgk-plus" data-oneu>${ic('plus', 13)} Objekt</button><div data-oform></div>`;
      const form = (o) => {
        const f = el.querySelector('[data-oform]');
        f.innerHTML = `<div class="kgk-form"><div class="kgk-row"><div class="kgk-fld"><label>Bezeichnung</label><input data-f="name" placeholder="z. B. Ferienhaus, Liegenschaft" value="${esc(o?.name || '')}"></div></div>
          <div class="kgk-row"><div class="kgk-fld" style="flex:2"><label>Strasse/Hausnummer</label><input data-f="strasse" value="${esc(o?.strasse || '')}"></div>
          <div class="kgk-fld" style="flex:.7"><label>PLZ</label><input data-f="plz" maxlength="5" value="${esc(o?.plz || '')}"></div>
          <div class="kgk-fld" style="flex:1.3"><label>Ort</label><input data-f="ort" value="${esc(o?.ort || '')}"></div></div>
          <div class="kgk-err"></div>
          <div class="kgk-btns" style="margin-top:6px"><button type="button" class="kgk-b g" data-x>Abbrechen</button><button type="button" class="kgk-b" data-s>${o ? 'Speichern' : 'Hinzufügen'}</button></div></div>`;
        f.querySelectorAll('input').forEach(i => i.setAttribute('autocomplete', 'off'));
        f.querySelector('input').focus();
        f.querySelector('[data-x]').onclick = () => { f.innerHTML = ''; };
        f.querySelector('[data-s]').onclick = async () => {
          const v = {}; f.querySelectorAll('[data-f]').forEach(i => v[i.dataset.f] = i.value.trim() || null);
          if(!v.strasse && !v.ort){ f.querySelector('.kgk-err').textContent = 'Bitte mindestens Strasse oder Ort angeben.'; return; }
          const { error } = o ? await sb.from('kunde_objekt').update(v).eq('id', o.id) : await sb.from('kunde_objekt').insert({ ...v, kunde_id: kundeId });
          if(error){ f.querySelector('.kgk-err').textContent = error.message; return; }
          await zeichne(); nachher && nachher();
        };
      };
      el.querySelector('[data-oneu]').onclick = () => form(null);
      el.querySelectorAll('[data-oed]').forEach(b => b.onclick = () => form(liste.find(x => x.id === b.dataset.oed)));
      el.querySelectorAll('[data-oweg]').forEach(b => b.onclick = async () => {
        const o = liste.find(x => x.id === b.dataset.oweg);
        if(!confirm(`Objekt «${o.name || adrText(o)}» löschen?`)) return;
        const { error } = await sb.from('kunde_objekt').delete().eq('id', o.id);
        if(error){ alert(error.code === '23503' ? 'Kann nicht gelöscht werden – an diesem Objekt hängen noch Offerten.' : error.message); return; }
        await zeichne(); nachher && nachher();
      });
    };
    await zeichne();
  };

  // ------------------------------------------------------------------ Verknüpfungen verwalten
  async function sucheKunden(q, ohne){
    const w = q.trim().split(/\s+/).filter(x => x.length > 1);
    if(!w.length) return [];
    let r = sb.from('kunde').select('id,name,strasse,plz,ort,inaktiv').neq('id', ohne).order('inaktiv').order('name').limit(12);
    w.forEach(x => { const s = x.replace(/[%,()]/g, ''); r = r.or(`name.ilike.%${s}%,strasse.ilike.%${s}%,ort.ilike.%${s}%,plz.ilike.%${s}%,kundennummer.ilike.%${s}%`); });
    const { data } = await r; return data || [];
  }
  K.verknuepfungenVerwalten = async (el, kundeId, nachher) => {
    stil();
    const zeichne = async () => {
      const { data } = await sb.from('kunde_beziehung').select('*, von:kunde_von(id,name,ort,inaktiv), zu:kunde_zu(id,name,ort,inaktiv)').or(`kunde_von.eq.${kundeId},kunde_zu.eq.${kundeId}`);
      const liste = data || [];
      el.innerHTML = `<div class="kgk-liste">${liste.map(b => { const t = K.bezText(b, kundeId);
          return `<div class="kgk-z"><span class="t"><span>${esc(t.art)}:</span> <a href="tool-d-kunden-live-v1.html?kunde=${t.andereId}"><b>${esc(t.andere?.name || '')}</b></a>${t.andere?.ort ? ' <span>· ' + esc(t.andere.ort) + '</span>' : ''}${t.andere?.inaktiv ? '<span class="kgk-inaktiv">inaktiv</span>' : ''}</span>
          <button type="button" class="kg-ibtn danger" data-bweg="${b.id}" title="Verknüpfung entfernen" aria-label="Verknüpfung entfernen">${ic('trash', 13)}</button></div>`; }).join('')
        || '<div class="kgk-leer">Keine Verknüpfung.</div>'}</div>
        <button type="button" class="kgk-plus" data-bneu>${ic('plus', 13)} Verknüpfen</button><div data-bform></div>`;
      el.querySelectorAll('[data-bweg]').forEach(b => b.onclick = async () => {
        if(!confirm('Verknüpfung entfernen? Die beiden Kunden bleiben bestehen.')) return;
        const { error } = await sb.from('kunde_beziehung').delete().eq('id', b.dataset.bweg);
        if(error){ alert(error.message); return; }
        await zeichne(); nachher && nachher();
      });
      el.querySelector('[data-bneu]').onclick = () => {
        const f = el.querySelector('[data-bform]'); let gewaehlt = null, treffer = [], t = null;
        f.innerHTML = `<div class="kgk-form">
          <div class="kgk-row"><div class="kgk-fld" style="flex:2"><label>Kunde (auch inaktive)</label><input data-q placeholder="Name, Strasse, Ort …" autocomplete="off" data-lpignore="true" data-1p-ignore="true" data-form-type="other"></div>
          <div class="kgk-fld"><label>Art</label><select data-art>${ARTEN.map(a => `<option value="${a.k}">${a.n}</option>`).join('')}</select></div></div>
          <div class="kgk-treffer" data-tr hidden></div>
          <label class="kgk-chk" data-inakt><input type="checkbox" checked> Vorbesitzer inaktiv setzen (bleibt mit allen Daten erhalten)</label>
          <div class="kgk-err"></div>
          <div class="kgk-btns" style="margin-top:6px"><button type="button" class="kgk-b g" data-x>Abbrechen</button><button type="button" class="kgk-b" data-s disabled>Verknüpfen</button></div></div>`;
        const q = f.querySelector('[data-q]'), tr = f.querySelector('[data-tr]'), sel = f.querySelector('[data-art]'), ok = f.querySelector('[data-s]'), ina = f.querySelector('[data-inakt]');
        const artWechsel = () => { ina.hidden = sel.value !== 'vorbesitzer'; ina.querySelector('input').checked = !(gewaehlt && gewaehlt.inaktiv); if(gewaehlt && gewaehlt.inaktiv) ina.hidden = true; };
        sel.onchange = artWechsel; artWechsel(); q.focus();
        q.oninput = () => { gewaehlt = null; ok.disabled = true; clearTimeout(t); t = setTimeout(async () => {
          treffer = await sucheKunden(q.value, kundeId);
          tr.hidden = !q.value.trim();
          tr.innerHTML = treffer.map((k, i) => `<button type="button" data-i="${i}"><b>${esc(k.name)}${k.inaktiv ? '<span class="kgk-inaktiv">inaktiv</span>' : ''}</b><span>${esc(adrText(k))}</span></button>`).join('') || '<div class="kgk-leer" style="padding:6px 9px">Kein Kunde gefunden.</div>';
          tr.querySelectorAll('[data-i]').forEach(b => b.onclick = () => { gewaehlt = treffer[+b.dataset.i]; q.value = gewaehlt.name + (gewaehlt.ort ? ', ' + gewaehlt.ort : ''); tr.hidden = true; ok.disabled = false; artWechsel(); });
        }, 220); };
        f.querySelector('[data-x]').onclick = () => { f.innerHTML = ''; };
        ok.onclick = async () => {
          if(!gewaehlt) return;
          const a = ARTEN.find(x => x.k === sel.value);
          const zeile = a.ich === 'zu' ? { kunde_von: gewaehlt.id, kunde_zu: kundeId, art: a.art } : { kunde_von: kundeId, kunde_zu: gewaehlt.id, art: a.art };
          const { error } = await sb.from('kunde_beziehung').insert(zeile);
          if(error){ f.querySelector('.kgk-err').textContent = error.code === '23505' ? 'Diese Verknüpfung gibt es schon.' : error.message; return; }
          if(a.k === 'vorbesitzer' && !ina.hidden && ina.querySelector('input').checked)
            await sb.from('kunde').update({ inaktiv: true, inaktiv_seit: new Date().toISOString().slice(0, 10) }).eq('id', gewaehlt.id);
          await zeichne(); nachher && nachher();
        };
      };
    };
    await zeichne();
  };

  // ------------------------------------------------------------------ Fenster fürs Offertentool
  K.fenster = async (kundeId, opt = {}) => {
    const [{ data: k }, { data: objekte }, of] = await Promise.all([
      sb.from('kunde').select('*').eq('id', kundeId).maybeSingle(),
      sb.from('kunde_objekt').select('*').eq('kunde_id', kundeId).order('reihenfolge').order('erstellt_am'),
      opt.offerteId ? sb.from('offerte').select('objekt_id,adresse_fix').eq('id', opt.offerteId).maybeSingle() : Promise.resolve({ data: null })]);
    if(!k){ alert('Kunde nicht gefunden.'); return; }
    const off = of.data || {};
    const fld = (f, l, st) => `<div class="kgk-fld"${st ? ` style="${st}"` : ''}><label>${l}</label><input data-k="${f}" value="${esc(k[f] || '')}" autocomplete="off" data-lpignore="true" data-1p-ignore="true" data-form-type="other"></div>`;
    const fix = off.adresse_fix;
    const o = overlay(`<h3>Kunde bearbeiten</h3>
      <div class="kgk-sub">${k.easybill_id ? 'Mit Easybill verknüpft – Änderungen gehen auch nach Easybill.' : 'Nur bei uns erfasst.'}</div>
      ${fix ? `<div class="kgk-fix"><span>Diese Offerte hat noch die frühere Adresse: <b>${esc(adrText(fix))}</b></span><button type="button" class="kgk-b g" data-fixweg>Neue übernehmen</button></div>` : ''}
      <div class="kgk-row">${fld('firma', 'Firma', 'flex:2')}</div>
      <div class="kgk-row">${fld('vorname', 'Vorname')}${fld('nachname', 'Nachname')}</div>
      <div class="kgk-row">${fld('strasse', 'Strasse/Hausnummer', 'flex:2')}${fld('plz', 'PLZ', 'flex:.7')}${fld('ort', 'Ort', 'flex:1.3')}</div>
      ${opt.offerteId ? `<h4>Arbeitsort dieser Offerte</h4>
      <div class="kgk-wahl" data-ort>
        <label class="${!off.objekt_id ? 'an' : ''}"><input type="radio" name="kgkobj" value=""${!off.objekt_id ? ' checked' : ''}><span><b>Kundenadresse</b><small>${esc(adrText(fix || k) || '–')}</small></span></label>
        ${(objekte || []).map(x => `<label class="${off.objekt_id === x.id ? 'an' : ''}"><input type="radio" name="kgkobj" value="${x.id}"${off.objekt_id === x.id ? ' checked' : ''}><span><b>${esc(x.name || 'Objekt')}</b><small>${esc(adrText(x))}</small></span></label>`).join('')}
        <label><input type="radio" name="kgkobj" value="neu"><span><b>Neues Objekt …</b><small>Andere Liegenschaft dieses Kunden</small></span></label>
      </div>
      <div data-neuobj hidden class="kgk-form">
        <div class="kgk-row"><div class="kgk-fld"><label>Bezeichnung</label><input data-n="name" placeholder="z. B. Neues Haus, Ferienhaus"></div></div>
        <div class="kgk-row"><div class="kgk-fld" style="flex:2"><label>Strasse/Hausnummer</label><input data-n="strasse"></div><div class="kgk-fld" style="flex:.7"><label>PLZ</label><input data-n="plz" maxlength="5"></div><div class="kgk-fld" style="flex:1.3"><label>Ort</label><input data-n="ort"></div></div>
      </div>
      <div class="kgk-hin">Fahrzeit und Werke rechnen mit dem Arbeitsort.</div>` : ''}
      <div class="kgk-err"></div>
      <div class="kgk-btns"><a class="kgk-b l kgk-links" href="tool-d-kunden-live-v1.html?kunde=${k.id}">In Kontakte öffnen</a><button type="button" class="kgk-b g" data-ab>Abbrechen</button><button type="button" class="kgk-b" data-ok>Speichern</button></div>`);
    const err = o.querySelector('.kgk-err');
    let fixWeg = false;
    o.querySelector('[data-fixweg]')?.addEventListener('click', e => { fixWeg = true; e.currentTarget.closest('.kgk-fix').innerHTML = '<span>Die Offerte bekommt beim Speichern die aktuelle Kundenadresse.</span>'; });
    o.querySelectorAll('input[name=kgkobj]').forEach(r => r.addEventListener('change', () => {
      o.querySelectorAll('[data-ort] label').forEach(l => l.classList.toggle('an', l.querySelector('input').checked));
      o.querySelector('[data-neuobj]').hidden = r.value !== 'neu';
      if(r.value === 'neu') o.querySelector('[data-n=name]').focus(); }));
    const zu = () => o.remove();
    o.querySelector('[data-ab]').onclick = zu;
    o.addEventListener('keydown', e => { if(e.key === 'Escape') zu(); });
    o.querySelector('[data-ok]').onclick = async () => {
      err.textContent = '';
      const neu = { ...k }; o.querySelectorAll('[data-k]').forEach(i => neu[i.dataset.k] = i.value.trim() || null);
      neu.name = neu.firma || [neu.vorname, neu.nachname].filter(Boolean).join(' ').trim();
      if(!neu.name){ err.textContent = 'Bitte Firma oder Name ausfüllen.'; return; }
      const geaendert = ['firma', 'vorname', 'nachname', 'strasse', 'plz', 'ort'].some(f => (k[f] || null) !== (neu[f] || null));
      const knopf = o.querySelector('[data-ok]'); knopf.disabled = true;
      let meldung = '';
      try{
        if(geaendert){
          o.style.display = 'none';
          const r = await K.speichern(k, { name: neu.name, firma: neu.firma, vorname: neu.vorname, nachname: neu.nachname, strasse: neu.strasse, plz: neu.plz, ort: neu.ort });
          o.style.display = '';
          if(!r){ knopf.disabled = false; return; }
          if(!r.ok){ err.textContent = r.text; knopf.disabled = false; return; }
          meldung = r.text; if(r.warnung) alert(r.text);
        }
        if(opt.offerteId){
          const w = o.querySelector('input[name=kgkobj]:checked')?.value ?? '';
          const upd = {};
          if(w === 'neu'){
            const v = {}; o.querySelectorAll('[data-n]').forEach(i => v[i.dataset.n] = i.value.trim() || null);
            if(!v.strasse && !v.ort){ err.textContent = 'Bitte beim neuen Objekt mindestens Strasse oder Ort angeben.'; knopf.disabled = false; return; }
            const { data: no, error } = await sb.from('kunde_objekt').insert({ ...v, kunde_id: k.id }).select('id').single();
            if(error){ err.textContent = error.message; knopf.disabled = false; return; }
            upd.objekt_id = no.id;
          } else if((w || null) !== (off.objekt_id || null)) upd.objekt_id = w || null;
          if(fixWeg) upd.adresse_fix = null;
          if(Object.keys(upd).length){
            const { error } = await sb.from('offerte').update(upd).eq('id', opt.offerteId);
            if(error){ err.textContent = error.message; knopf.disabled = false; return; }
          }
        }
      } catch(e){ err.textContent = String(e.message || e); knopf.disabled = false; return; }
      zu();
      opt.onSaved && opt.onSaved(meldung);
    };
  };

  // Arbeitsort einer Offerte: Objekt > eingefrorene Adresse > Kunde  -> { name, strasse, plz, ort, quelle }
  K.arbeitsort = async (offerteId, kunde) => {
    const { data: of } = await sb.from('offerte').select('objekt_id,adresse_fix,objekt:objekt_id(id,name,strasse,plz,ort)').eq('id', offerteId).maybeSingle();
    if(of?.objekt) return { ...of.objekt, quelle: 'objekt', objektName: of.objekt.name, fix: of.adresse_fix };
    if(of?.adresse_fix) return { ...of.adresse_fix, quelle: 'fix' };
    return kunde ? { name: kunde.name, strasse: kunde.strasse, plz: kunde.plz, ort: kunde.ort, quelle: 'kunde' } : null;
  };
})();
