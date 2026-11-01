/* kg-infos.js – Infos vom Büro an die Mitarbeitenden (wird von kg-stil.js automatisch geladen).
   Empfänger:  Pop-ups erscheinen in jedem Tool und müssen bestätigt werden.
               Balken erscheinen dort, wo die Seite <div data-kg-infos></div> hat (Startseite), mit × wegklickbar.
   Büro:       KG.infos.neu()                 – Fenster «Neue Info»
               KG.infos.liste(el, { alle })   – Liste mit Status, «gelesen von», Bearbeiten/Löschen
                                                (alle = auch abgelaufene, sonst nur aktuelle und geplante)
   Daten: mitarbeiter_info, mitarbeiter_info_gelesen, rpc mitarbeiter_info_lesestand. Recht: verw.infos.* */
(function(){
  window.KG = window.KG || {};
  if(KG.infos) return;
  const FARBE = (KG.palette && KG.palette.orange[1]) || '#C05A1C';
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const ic = (n, g) => KG.icon ? KG.icon(n, g || 14) : '';
  const sb = () => {
    if(!KG._sb && window.supabase && window.supabase.createClient)
      KG._sb = window.supabase.createClient('https://oalapdxinqlnzwxhyuzy.supabase.co', 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P');
    return KG._sb;
  };

  const css = `
.kgi-balken{background:${FARBE};color:#fff;border-radius:10px;padding:10px 12px 10px 16px;display:flex;gap:12px;align-items:flex-start;margin:0 0 10px;}
.kgi-balken .t{flex:1;font-size:14px;line-height:1.45;}
.kgi-balken .t small{display:block;font-size:12px;opacity:.85;margin-top:2px;}
.kgi-balken button{flex:none;width:28px;height:28px;border:none;border-radius:50%;background:transparent;color:#fff;cursor:pointer;display:grid;place-items:center;opacity:.85;}
.kgi-balken button:hover{background:rgba(255,255,255,.18);opacity:1;}
.kgi-balken button svg{width:18px;height:18px;}
.kgi-ov{position:fixed;inset:0;background:rgba(35,43,53,.45);z-index:10050;display:grid;place-items:center;padding:16px;}
.kgi-box{background:#fff;border-radius:14px;max-width:460px;width:100%;box-shadow:0 18px 50px rgba(0,0,0,.25);overflow:hidden;font-family:inherit;color:#232B35;}
.kgi-box .kopf{background:${FARBE};color:#fff;padding:14px 18px;font-size:16px;font-weight:700;line-height:1.35;}
.kgi-box .kopf small{display:block;font-size:12px;font-weight:400;opacity:.85;margin-top:3px;}
.kgi-box .inh{padding:16px 18px;font-size:14px;line-height:1.55;white-space:pre-wrap;}
.kgi-box .fuss{padding:0 18px 16px;display:flex;justify-content:flex-end;gap:8px;}
.kgi-btn{border:1px solid #323E4E;background:#323E4E;color:#fff;border-radius:8px;padding:8px 16px;font:inherit;font-size:14px;font-weight:600;cursor:pointer;}
.kgi-btn.ghost{background:#fff;color:#323E4E;border-color:#E1E5E9;}
.kgi-btn:disabled{opacity:.5;cursor:default;}
.kgi-ed{max-width:540px;}
.kgi-ed .kopf{background:#323E4E;}
.kgi-ed .inh{white-space:normal;display:flex;flex-direction:column;gap:12px;}
.kgi-ed label.l{display:block;font-size:12px;font-weight:600;color:#4C5C70;margin-bottom:4px;}
.kgi-ed input[type=text],.kgi-ed input[type=date],.kgi-ed textarea{width:100%;box-sizing:border-box;border:1px solid #E1E5E9;border-radius:8px;padding:8px 10px;font:inherit;font-size:14px;color:#232B35;background:#fff;}
.kgi-ed textarea{min-height:80px;resize:vertical;}
.kgi-ed .zeile{display:flex;gap:10px;}.kgi-ed .zeile>div{flex:1;}
.kgi-seg{display:flex;gap:6px;flex-wrap:wrap;}
.kgi-seg button{border:1px solid #E1E5E9;background:#fff;color:#4C5C70;border-radius:999px;padding:6px 12px;font:inherit;font-size:13px;cursor:pointer;}
.kgi-seg button.on{background:#323E4E;border-color:#323E4E;color:#fff;}
.kgi-ed .hw{font-size:12px;color:#6B7079;margin-top:4px;}
.kgi-ed .fehler{color:#B4655F;font-size:13px;}
.kgi-liste{display:flex;flex-direction:column;}
.kgi-z{display:flex;gap:10px;align-items:flex-start;padding:9px 0;border-bottom:1px solid #EEF1F4;}
.kgi-z:last-child{border-bottom:none;}
.kgi-z .t{flex:1;min-width:0;font-size:13.5px;line-height:1.4;}
.kgi-z .t b{color:#232B35;}
.kgi-z .t small{display:block;color:#6B7079;font-size:12px;margin-top:1px;}
.kgi-z .k{display:flex;gap:6px;flex:none;}
.kgi-pill{display:inline-block;font-size:11px;font-weight:600;border-radius:999px;padding:1px 8px;margin-right:6px;vertical-align:1px;}
.kgi-pill.akt{background:${FARBE};color:#fff;}.kgi-pill.gep{background:#DCE2E8;color:#323E4E;}.kgi-pill.alt{background:#F1F3F5;color:#8B9097;}
.kgi-gel{border:none;background:none;padding:0;font:inherit;font-size:12px;color:#2F5C9A;cursor:pointer;text-decoration:underline;}
.kgi-wer{margin-top:6px;display:flex;flex-wrap:wrap;gap:4px;}
.kgi-wer span{font-size:11.5px;border-radius:999px;padding:1px 8px;background:#EEF3F7;color:#323E4E;}
.kgi-wer span.nein{background:#fff;border:1px dashed #C9CED4;color:#8B9097;}
.kgi-leer{color:#8B9097;font-size:13px;padding:8px 0;}`;
  const st = document.createElement('style'); st.id = 'kg-infos'; st.textContent = css;
  (document.head || document.documentElement).appendChild(st);

  const datum = d => new Date(d).toLocaleDateString('de-CH', { day: 'numeric', month: 'numeric' });
  const wann = d => {
    const x = new Date(d), h = new Date(); h.setHours(0, 0, 0, 0);
    const zeit = x.toLocaleTimeString('de-CH', { hour: '2-digit', minute: '2-digit' });
    return x >= h ? `heute ${zeit}` : x >= new Date(h - 864e5) ? `gestern ${zeit}` : `${datum(x)} ${zeit}`;
  };
  const isoTag = d => { const x = new Date(d); return `${x.getFullYear()}-${String(x.getMonth() + 1).padStart(2, '0')}-${String(x.getDate()).padStart(2, '0')}`; };
  const zeitraum = i => {
    const bis = i.gueltig_bis ? new Date(new Date(i.gueltig_bis) - 1) : null;
    if(bis && isoTag(bis) === isoTag(i.gueltig_von)) return datum(i.gueltig_von);
    return `${datum(i.gueltig_von)} – ${bis ? datum(bis) : 'offen'}`;
  };
  const status = i => { const n = Date.now();
    return new Date(i.gueltig_von) > n ? 'gep' : i.gueltig_bis && new Date(i.gueltig_bis) <= n ? 'alt' : 'akt'; };

  /* ---------------- Empfänger: Balken + Pop-ups ---------------- */
  let gestartet = false, ich = null;
  async function start(){
    if(gestartet) return;
    const c = sb(); if(!c) return;
    const { data: { session } } = await c.auth.getSession();
    if(!session) return;
    gestartet = true; ich = session.user.id;
    const jetzt = new Date().toISOString();
    const [{ data: ben }, { data: infos }, { data: gel }] = await Promise.all([
      c.from('benutzer').select('recht_gruppe_id').eq('id', ich).maybeSingle(),
      c.from('mitarbeiter_info').select('id,titel,text,art,gruppen,gueltig_von,gueltig_bis,erstellt_am')
        .lte('gueltig_von', jetzt).or(`gueltig_bis.is.null,gueltig_bis.gt.${jetzt}`).order('erstellt_am', { ascending: false }),
      c.from('mitarbeiter_info_gelesen').select('info_id').eq('benutzer_id', ich)]);
    const meine = ben && ben.recht_gruppe_id, gelesen = new Set((gel || []).map(g => g.info_id));
    const offen = (infos || []).filter(i => !gelesen.has(i.id) && (!i.gruppen || !i.gruppen.length || i.gruppen.includes(meine)));
    balken(offen.filter(i => i.art === 'balken'));
    popups(offen.filter(i => i.art === 'popup').reverse());
  }
  const merke = id => sb().from('mitarbeiter_info_gelesen').insert({ info_id: id, benutzer_id: ich }).then(({ error }) => { if(error) console.error(error); });

  function balken(liste){
    const ziel = document.querySelector('[data-kg-infos]'); if(!ziel) return;
    ziel.classList.add('kgi-wrap');
    ziel.innerHTML = liste.map(i => `<div class="kgi-balken" data-id="${i.id}"><div class="t"><b>${esc(i.titel)}</b>${i.text ? ' – ' + esc(i.text) : ''}<small>Info vom Büro · ${wann(i.erstellt_am)}</small></div>
      <button type="button" aria-label="Info ausblenden" title="Ausblenden">${ic('x', 18)}</button></div>`).join('');
    ziel.querySelectorAll('.kgi-balken button').forEach(b => b.addEventListener('click', () => { const z = b.closest('.kgi-balken'); merke(z.dataset.id); z.remove(); }));
  }

  function popups(liste){
    const i = liste.shift(); if(!i) return;
    const ov = document.createElement('div'); ov.className = 'kgi-ov';
    ov.innerHTML = `<div class="kgi-box" role="dialog" aria-modal="true"><div class="kopf">${esc(i.titel)}<small>Info vom Büro · ${wann(i.erstellt_am)}</small></div>
      ${i.text ? `<div class="inh">${esc(i.text)}</div>` : '<div style="height:16px"></div>'}<div class="fuss"><button type="button" class="kgi-btn">Verstanden</button></div></div>`;
    document.body.appendChild(ov);
    ov.querySelector('.kgi-btn').addEventListener('click', () => { merke(i.id); ov.remove(); popups(liste); });
  }

  function beobachten(){
    start();
    const ub = document.getElementById('userbar'); // die Seiten blenden die Leiste nach dem Login ein
    if(ub) new MutationObserver(() => { if(!ub.classList.contains('hidden')) start(); }).observe(ub, { attributes: true, attributeFilter: ['class'] });
  }

  /* ---------------- Büro: Neue Info / Bearbeiten ---------------- */
  let gruppenCache = null;
  const ladeGruppen = async () => gruppenCache || (gruppenCache = ((await sb().from('recht_gruppe').select('id,name,ist_admin').order('sortierung')).data || []));

  async function neu(alt){
    const gruppen = await ladeGruppen();
    const heute = isoTag(new Date());
    const z = { art: alt ? alt.art : 'balken', gruppen: new Set((alt && alt.gruppen) || []) };
    const ov = document.createElement('div'); ov.className = 'kgi-ov';
    ov.innerHTML = `<div class="kgi-box kgi-ed" role="dialog" aria-modal="true"><div class="kopf">${alt ? 'Info bearbeiten' : 'Neue Info an Mitarbeitende'}</div>
      <div class="inh">
        <div><label class="l">Titel</label><input type="text" data-f="titel" maxlength="120" placeholder="z. B. Achtung: Strassen glitschig" value="${esc(alt ? alt.titel : '')}"></div>
        <div><label class="l">Text (optional)</label><textarea data-f="text" placeholder="z. B. Vorsichtig fahren, Winterpneus kontrollieren.">${esc(alt ? alt.text || '' : '')}</textarea></div>
        <div><label class="l">Wie anzeigen?</label><div class="kgi-seg" data-seg="art">
          <button type="button" data-v="balken">Balken auf der Startseite</button><button type="button" data-v="popup">Pop-up, muss bestätigt werden</button></div>
          <div class="hw" data-hw="art"></div></div>
        <div><label class="l">An wen?</label><div class="kgi-seg" data-seg="gruppen">
          <button type="button" data-v="">Alle</button>${gruppen.map(g => `<button type="button" data-v="${g.id}">${esc(g.name)}</button>`).join('')}</div></div>
        <div class="zeile"><div><label class="l">Ab</label><input type="date" data-f="von" value="${alt ? isoTag(alt.gueltig_von) : heute}"></div>
          <div><label class="l">Bis und mit</label><input type="date" data-f="bis" value="${alt ? (alt.gueltig_bis ? isoTag(new Date(new Date(alt.gueltig_bis) - 1)) : '') : heute}"></div></div>
        <div class="hw" style="margin-top:-6px">«Bis» leer lassen = bleibt, bis du die Info löschst.</div>
        <div class="fehler" data-fehler></div>
      </div>
      <div class="fuss"><button type="button" class="kgi-btn ghost" data-k="ab">Abbrechen</button><button type="button" class="kgi-btn" data-k="ok">${alt ? 'Speichern' : 'Senden'}</button></div></div>`;
    document.body.appendChild(ov);
    const $ = s => ov.querySelector(s);
    const zeigen = () => {
      ov.querySelectorAll('[data-seg="art"] button').forEach(b => b.classList.toggle('on', b.dataset.v === z.art));
      ov.querySelectorAll('[data-seg="gruppen"] button').forEach(b => b.classList.toggle('on', b.dataset.v ? z.gruppen.has(b.dataset.v) : !z.gruppen.size));
      $('[data-hw="art"]').textContent = z.art === 'popup' ? 'Erscheint in jedem Tool als Fenster, bis man «Verstanden» drückt.' : 'Erscheint oben auf der Startseite (Handy und Computer), mit × wegklickbar.';
    };
    ov.querySelectorAll('[data-seg="art"] button').forEach(b => b.addEventListener('click', () => { z.art = b.dataset.v; zeigen(); }));
    ov.querySelectorAll('[data-seg="gruppen"] button').forEach(b => b.addEventListener('click', () => {
      const v = b.dataset.v; if(!v) z.gruppen.clear(); else if(z.gruppen.has(v)) z.gruppen.delete(v); else z.gruppen.add(v); zeigen(); }));
    zeigen();
    $('[data-f="titel"]').focus();
    $('[data-k="ab"]').addEventListener('click', () => ov.remove());
    $('[data-k="ok"]').addEventListener('click', async () => {
      const titel = $('[data-f="titel"]').value.trim(), von = $('[data-f="von"]').value, bis = $('[data-f="bis"]').value;
      const fehler = t => { $('[data-fehler]').textContent = t; };
      if(!titel) return fehler('Bitte einen Titel eingeben.');
      if(!von) return fehler('Bitte ein Startdatum wählen.');
      if(bis && bis < von) return fehler('«Bis» liegt vor «Ab».');
      // Ab heute = sofort; Bis = Ende des gewählten Tages
      const vonD = von === heute && !(alt && isoTag(alt.gueltig_von) === heute) ? new Date() : (alt && isoTag(alt.gueltig_von) === von ? new Date(alt.gueltig_von) : new Date(von + 'T00:00'));
      const bisD = bis ? new Date(new Date(bis + 'T00:00').getTime() + 864e5) : null;
      const daten = { titel, text: $('[data-f="text"]').value.trim() || null, art: z.art, gruppen: z.gruppen.size ? [...z.gruppen] : null,
        gueltig_von: vonD.toISOString(), gueltig_bis: bisD ? bisD.toISOString() : null };
      const knopf = $('[data-k="ok"]'); knopf.disabled = true;
      const { error } = alt ? await sb().from('mitarbeiter_info').update(daten).eq('id', alt.id) : await sb().from('mitarbeiter_info').insert(daten);
      if(error){ knopf.disabled = false; return fehler('Konnte nicht gespeichert werden: ' + error.message); }
      ov.remove(); document.dispatchEvent(new CustomEvent('kg-infos-geaendert'));
    });
  }

  /* ---------------- Büro: Liste ---------------- */
  async function liste(el, opt){
    opt = opt || {};
    const laden = async () => {
      if(!el.isConnected) return;
      el.innerHTML = '<div class="kgi-leer">Lädt …</div>';
      if(KG.ladeRechte) await KG.ladeRechte();
      const [gruppen, { data, error }] = await Promise.all([ladeGruppen(),
        sb().from('mitarbeiter_info').select('id,titel,text,art,gruppen,gueltig_von,gueltig_bis,erstellt_von,erstellt_am').order('gueltig_von', { ascending: false }).limit(opt.alle ? 100 : 40)]);
      if(error){ el.innerHTML = '<div class="kgi-leer">Infos konnten nicht geladen werden.</div>'; return; }
      const G = Object.fromEntries(gruppen.map(g => [g.id, g.name]));
      const reihe = { akt: 0, gep: 1, alt: 2 };
      const rows = (data || []).filter(i => opt.alle || status(i) !== 'alt').sort((a, b) => reihe[status(a)] - reihe[status(b)]);
      if(!rows.length){ el.innerHTML = `<div class="kgi-leer">${opt.alle ? 'Noch keine Infos.' : 'Im Moment keine Infos aktiv.'}</div>`; return; }
      const darf = (a, i) => !KG.darfBei || KG.darfBei('verw', 'infos', a, i.erstellt_von) !== false;
      el.innerHTML = `<div class="kgi-liste">${rows.map(i => { const s = status(i);
        return `<div class="kgi-z" data-id="${i.id}"><div class="t"><span class="kgi-pill ${s}">${{ akt: 'Aktiv', gep: 'Geplant', alt: 'Abgelaufen' }[s]}</span><b>${esc(i.titel)}</b>
          <small>${i.art === 'popup' ? 'Pop-up' : 'Balken'} · ${i.gruppen && i.gruppen.length ? i.gruppen.map(g => esc(G[g] || '?')).join(', ') : 'Alle'} · ${zeitraum(i)} · <button type="button" class="kgi-gel" data-gel>gelesen …</button></small>
          <div class="kgi-wer" data-wer style="display:none"></div></div>
          <div class="k">${darf('bearbeiten', i) ? `<button type="button" class="kg-ibtn" data-ed title="Bearbeiten" aria-label="Bearbeiten">${ic('edit')}</button>` : ''}${darf('loeschen', i) ? `<button type="button" class="kg-ibtn danger" data-weg title="Löschen" aria-label="Löschen">${ic('trash')}</button>` : ''}</div></div>`; }).join('')}</div>`;
      // «x von y gelesen» pro Info
      rows.forEach(async i => {
        const z = el.querySelector(`.kgi-z[data-id="${i.id}"]`); if(!z) return;
        const { data: ls } = await sb().rpc('mitarbeiter_info_lesestand', { p_info: i.id });
        const l = ls || [], ja = l.filter(x => x.gelesen_am);
        const b = z.querySelector('[data-gel]'); b.textContent = `${ja.length} von ${l.length} gelesen`;
        z.querySelector('[data-wer]').innerHTML = l.map(x => `<span class="${x.gelesen_am ? '' : 'nein'}" title="${x.gelesen_am ? 'gelesen ' + wann(x.gelesen_am) : 'noch nicht gelesen'}">${esc(x.name)}</span>`).join('') || '<span class="nein">niemand</span>';
      });
      el.querySelectorAll('[data-gel]').forEach(b => b.addEventListener('click', () => { const w = b.closest('.kgi-z').querySelector('[data-wer]'); w.style.display = w.style.display === 'none' ? '' : 'none'; }));
      el.querySelectorAll('[data-ed]').forEach(b => b.addEventListener('click', () => neu(rows.find(i => i.id === b.closest('.kgi-z').dataset.id))));
      el.querySelectorAll('[data-weg]').forEach(b => b.addEventListener('click', async () => {
        const i = rows.find(x => x.id === b.closest('.kgi-z').dataset.id);
        if(!confirm(`Info «${i.titel}» löschen?`)) return;
        const { error: e2 } = await sb().from('mitarbeiter_info').delete().eq('id', i.id);
        if(e2){ alert('Konnte nicht gelöscht werden: ' + e2.message); return; }
        laden();
      }));
    };
    if(!el._kgiHoert){ el._kgiHoert = true; document.addEventListener('kg-infos-geaendert', laden); }
    await laden();
  }

  KG.infos = { start, neu, liste, farbe: FARBE };
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', beobachten); else beobachten();
})();
