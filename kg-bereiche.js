/* Knechtgarten – Bereiche pro Kunde (A Südseite, B Nordseite …)
   Gemeinsamer Baustein für Offertenliste (Neue Offerte, Bereich zuweisen) und Offerte (Blatt).
   Tabelle kunde_bereich: Buchstabe fest (nie neu vergeben), Name änderbar, ausgeblendet = nicht mehr für neue Offerten.
   Nicht mehr benutzte Bereiche (2 Jahre keine Offerte) erscheinen erst nach «ältere Bereiche anzeigen».

   KGBereiche.laden(sb, kundeId)                         -> [{ id, buchstabe, name, ausgeblendet, erstellt_am, n, letzte }]
   KGBereiche.picker(el, { sb, kundeId, wert, onWahl })  -> zeichnet Auswahl + «+ Bereich» + Bearbeiten in el
   KGBereiche.badge(b, klein)                            -> HTML-Abzeichen mit Buchstabe (Name im Mouse-over) */
(function(){
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;' })[c]);
  const ic = (n, s) => (window.KG && KG.icon) ? KG.icon(n, s || 13) : '';
  const ZWEI_JAHRE = 2 * 365 * 864e5;
  const css = `
.kgb{display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.kgb button.kgb-c{font:inherit;font-size:12.5px;border:1px solid var(--line,#E1E5E9);background:#fff;color:var(--primary,#323E4E);border-radius:999px;padding:4px 11px 4px 5px;cursor:pointer;display:inline-flex;align-items:center;gap:6px;line-height:1.2}
.kgb button.kgb-c.kein{padding-left:11px}
.kgb button.kgb-c.on{background:var(--primary,#323E4E);color:#fff;border-color:var(--primary,#323E4E)}
.kgb .kgb-l{width:20px;height:20px;border-radius:50%;background:#DCE2E8;color:#323E4E;font-weight:600;font-size:11px;display:inline-flex;align-items:center;justify-content:center;flex:none}
.kgb button.kgb-c.on .kgb-l{background:#fff}
.kgb .kgb-plus{border-style:dashed !important;color:#8B9097 !important;padding-left:11px !important}
.kgb .kgb-alt{border:0;background:none;font:inherit;font-size:11.5px;color:#8B9097;cursor:pointer;padding:2px 4px;text-decoration:underline}
.kgb .kgb-e{display:inline-flex;align-items:center;gap:6px;border:1px solid var(--line,#E1E5E9);border-radius:999px;padding:3px 5px 3px 4px;background:#fff}
.kgb .kgb-e.neu{border-color:var(--primary,#323E4E)}
.kgb .kgb-e.aus{opacity:.55}
.kgb .kgb-e input{border:0;outline:none;background:transparent;font:inherit;font-size:12.5px;width:130px;color:var(--primary,#323E4E);padding:0}
.kgb .kgb-i{width:24px;height:24px;border-radius:50%;border:1px solid var(--line,#E1E5E9);background:#fff;color:#8B9097;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;padding:0;flex:none}
.kgb .kgb-i:hover{color:var(--primary,#323E4E);border-color:#8B9097}
.kgb .kgb-i.danger:hover{color:#B4655F;border-color:#B4655F}
.kgb .kgb-t{border:1px solid var(--line,#E1E5E9);background:#fff;font:inherit;font-size:11.5px;border-radius:6px;padding:3px 8px;cursor:pointer;color:var(--primary,#323E4E)}
.kgb .kgb-t.rot{color:#B4655F;border-color:#e7c3bf}
.kgb .kgb-frage{display:flex;gap:6px;align-items:center;flex-wrap:wrap;font-size:12px;color:var(--primary,#323E4E);background:#F5F7F9;border-radius:8px;padding:6px 8px;width:100%}
.kgb-badge{width:22px;height:22px;border-radius:50%;background:#DCE2E8;color:#323E4E;font-weight:600;font-size:11.5px;display:inline-flex;align-items:center;justify-content:center;cursor:help}
.kgb-badge.aus{opacity:.5}
.kgb-badge.klein{width:18px;height:18px;font-size:10.5px}`;
  const st = document.createElement('style'); st.id = 'kg-bereiche-stil'; st.textContent = css;
  (document.head || document.documentElement).appendChild(st);

  async function laden(sb, kundeId){
    if(!kundeId) return [];
    const [{ data: bs }, { data: os }] = await Promise.all([
      sb.from('kunde_bereich').select('id,buchstabe,name,ausgeblendet,erstellt_am').eq('kunde_id', kundeId).order('buchstabe'),
      sb.from('offerte').select('bereich_id,datum').eq('kunde_id', kundeId).not('bereich_id', 'is', null)
    ]);
    return (bs || []).map(b => { const eig = (os || []).filter(o => o.bereich_id === b.id);
      return { ...b, n: eig.length, letzte: eig.reduce((m, o) => (o.datum && o.datum > m ? o.datum : m), '') }; });
  }
  const naechster = liste => { const max = liste.reduce((m, b) => Math.max(m, (b.buchstabe || 'A').charCodeAt(0)), 64); return String.fromCharCode(max + 1); };
  const aktuell = (b, wert) => b.id === wert || (!b.ausgeblendet && (Date.now() - new Date(b.letzte || b.erstellt_am).getTime() < ZWEI_JAHRE));
  const titel = b => `Bereich ${b.buchstabe}${b.name ? ': ' + b.name : ''}${b.ausgeblendet ? ' (ausgeblendet)' : ''}`;
  const kurz = b => (b.name || 'Bereich ' + b.buchstabe) + (b.ausgeblendet ? ' (ausgeblendet)' : ''); // Mouse-over: nur der Name, der Buchstabe steht ja schon da
  const badge = (b, klein) => b ? `<span class="kgb-badge${klein ? ' klein' : ''}${b.ausgeblendet ? ' aus' : ''}" title="${esc(kurz(b))}">${esc(b.buchstabe)}</span>` : '';

  function picker(el, opt){
    const { sb, kundeId } = opt;
    let liste = [], wert = opt.wert || null, modus = 'wahl', neu = false, alteZeigen = false, frage = null;
    const wahl = id => { wert = id; zeichne(); opt.onWahl && opt.onWahl(id, liste.find(b => b.id === id) || null, liste); };
    const neuSpeichern = async inp => {
      const name = inp.value.trim(); neu = false;
      if(!name){ zeichne(); return; }
      const b = naechster(liste);
      const { data, error } = await sb.from('kunde_bereich').insert({ kunde_id: kundeId, buchstabe: b, name }).select().single();
      if(error){ alert('Bereich konnte nicht gespeichert werden: ' + error.message); zeichne(); return; }
      liste.push({ ...data, n: 0, letzte: '' }); wahl(data.id);
    };
    function zeichne(){
      if(!kundeId){ el.innerHTML = '<span style="font-size:12px;color:#8B9097">Zuerst einen Kunden wählen.</span>'; return; }
      const chip = b => `<button type="button" class="kgb-c${wert === b.id ? ' on' : ''}" data-id="${b.id}" title="${esc(titel(b))}"><span class="kgb-l">${esc(b.buchstabe)}</span>${esc(b.name || 'Bereich ' + b.buchstabe)}</button>`;
      if(modus === 'edit'){
        el.innerHTML = `<div class="kgb">${liste.map(b => `<span class="kgb-e${b.ausgeblendet ? ' aus' : ''}"><span class="kgb-l">${esc(b.buchstabe)}</span><input data-ren="${b.id}" value="${esc(b.name || '')}" placeholder="Bereich ${esc(b.buchstabe)}" autocomplete="off" data-lpignore="true" data-1p-ignore="true">`
          + (b.ausgeblendet ? `<button type="button" class="kgb-t" data-ein="${b.id}">Einblenden</button>` : `<button type="button" class="kgb-i danger" data-del="${b.id}" title="Ausblenden oder löschen">${ic('trash', 12)}</button>`) + `</span>`).join('')}`
          + `<button type="button" class="kgb-t" data-fertig>Fertig</button>`
          + (frage ? (() => { const b = liste.find(x => x.id === frage); return `<div class="kgb-frage">Bereich ${esc(b.buchstabe)}${b.name ? ' «' + esc(b.name) + '»' : ''}: <button type="button" class="kgb-t" data-aus="${b.id}">Für neue Offerten ausblenden</button><button type="button" class="kgb-t rot" data-weg="${b.id}">Ganz löschen${b.n ? ` (aus ${b.n} Offerte${b.n > 1 ? 'n' : ''} entfernen)` : ''}</button><button type="button" class="kgb-t" data-abbr>Abbrechen</button></div>`; })() : '')
          + `</div>`;
        return;
      }
      const sicht = liste.filter(b => aktuell(b, wert)), alt = liste.filter(b => !b.ausgeblendet && !aktuell(b, wert));
      const zeig = alteZeigen ? sicht.concat(alt) : sicht;
      el.innerHTML = `<div class="kgb">`
        + (zeig.length ? `<button type="button" class="kgb-c kein${!wert ? ' on' : ''}" data-id="">Kein Bereich</button>` + zeig.map(chip).join('') : '')
        + (alt.length && !alteZeigen ? `<button type="button" class="kgb-alt" data-alt>ältere Bereiche (${alt.length}) anzeigen</button>` : '')
        + (neu ? `<span class="kgb-e neu"><span class="kgb-l">${esc(naechster(liste))}</span><input data-neu placeholder="Name, z. B. Südseite" autocomplete="off" data-lpignore="true" data-1p-ignore="true"></span>`
               : `<button type="button" class="kgb-c kgb-plus" data-plus>+ ${liste.length ? 'Bereich' : 'Bereich anlegen'}</button>`)
        + (liste.length && !neu ? `<button type="button" class="kgb-i" data-edit title="Bereiche bearbeiten">${ic('edit', 12)}</button>` : '')
        + `</div>`;
      if(neu) setTimeout(() => el.querySelector('[data-neu]')?.focus(), 0);
    }
    el.onclick = async e => {
      e.stopPropagation();
      const t = e.target.closest('button'); if(!t) return;
      if(t.dataset.id !== undefined && modus === 'wahl'){ wahl(t.dataset.id || null); return; }
      if('plus' in t.dataset){ neu = true; zeichne(); return; }
      if('alt' in t.dataset){ alteZeigen = true; zeichne(); return; }
      if('edit' in t.dataset){ modus = 'edit'; frage = null; zeichne(); return; }
      if('fertig' in t.dataset){ modus = 'wahl'; frage = null; zeichne(); return; }
      if('abbr' in t.dataset){ frage = null; zeichne(); return; }
      if(t.dataset.del){ frage = t.dataset.del; zeichne(); return; }
      const setze = async (id, felder) => { const { error } = await sb.from('kunde_bereich').update(felder).eq('id', id); if(error){ alert(error.message); return false; } Object.assign(liste.find(b => b.id === id), felder); return true; };
      if(t.dataset.aus){ if(await setze(t.dataset.aus, { ausgeblendet: true })){ if(wert === t.dataset.aus && opt.neueOfferte) wahl(null); frage = null; zeichne(); } return; }
      if(t.dataset.ein){ if(await setze(t.dataset.ein, { ausgeblendet: false })) zeichne(); return; }
      if(t.dataset.weg){ const { error } = await sb.from('kunde_bereich').delete().eq('id', t.dataset.weg); if(error){ alert(error.message); return; }
        liste = liste.filter(b => b.id !== t.dataset.weg); frage = null; if(wert === t.dataset.weg) wahl(null); else zeichne(); opt.onGeloescht && opt.onGeloescht(); return; }
    };
    el.onkeydown = e => { const i = e.target;
      if(i.dataset.neu !== undefined){ if(e.key === 'Enter'){ e.preventDefault(); i.blur(); } if(e.key === 'Escape'){ i.value = ''; i.blur(); } }
      if(i.dataset.ren && e.key === 'Enter'){ e.preventDefault(); i.blur(); } };
    el.addEventListener('focusout', async e => { const i = e.target; if(!i.matches) return;
      if(i.matches('[data-neu]')) await neuSpeichern(i); // Enter oder Klick daneben speichert
      if(i.matches('[data-ren]')){ const b = liste.find(x => x.id === i.dataset.ren), n = i.value.trim() || null; if(b && n !== (b.name || null)){ const { error } = await sb.from('kunde_bereich').update({ name: n }).eq('id', b.id); if(!error){ b.name = n; opt.onWahl && wert === b.id && opt.onWahl(wert, b, liste); } } } });
    const api = { neuLaden: async () => { liste = await laden(sb, kundeId); zeichne(); return liste; }, wert: () => wert, liste: () => liste };
    zeichne(); api.neuLaden();
    return api;
  }
  window.KGBereiche = { laden, picker, badge, titel, kurz };
})();
