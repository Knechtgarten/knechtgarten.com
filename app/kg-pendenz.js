/* kg-pendenz.js – gemeinsame Pendenzen-Logik für Handy-Start, Pendenzen-App und Einsatzplaner.
   Einbinden nach supabase-js:  <script src="/kg-pendenz.js?v=1"></script>
   - Ansicht pro Gruppe (recht_gruppe.pendenzen_ansicht): «buero» = ganzes Pendenzen-Tool, «mitarbeiter» = nur Heute + Notizen
   - Mitarbeiter: Heute = Pendenz mit Zeit «Heute» (liegt in der versteckten Team-box), Notizen = Liste «Daten / Dauernde Notizen»
   - Büro: Erfassen unterwegs landet in der Sammelbox */
(function(){
  const cache = {};
  window.KGPZ = {
    // 'buero' oder 'mitarbeiter' für eine Person (ohne Gruppe: Büro)
    async ansicht(sb, uid){
      if(cache['a' + uid]) return cache['a' + uid];
      const { data: b } = await sb.from('benutzer').select('recht_gruppe_id').eq('id', uid).maybeSingle();
      let a = 'buero';
      if(b && b.recht_gruppe_id){ const { data: g } = await sb.from('recht_gruppe').select('pendenzen_ansicht').eq('id', b.recht_gruppe_id).maybeSingle(); if(g && g.pendenzen_ansicht) a = g.pendenzen_ansicht; }
      return (cache['a' + uid] = a);
    },
    // eigenes Board einer Person (fehlt es: schlank anlegen – Wann?, Team-box, Sammelbox, Notizen); Listen-IDs dazu
    async board(sb, uid){
      if(cache['b' + uid]) return cache['b' + uid];
      let { data: b } = await sb.from('pendenz_board').select('id').eq('typ', 'person').eq('besitzer_id', uid).maybeSingle();
      if(!b){ const r = await sb.from('pendenz_board').insert({ name: 'Mein Board', typ: 'person', besitzer_id: uid }).select('id').single(); if(r.error) throw r.error; b = r.data;
        const rows = [1, 2, 3].map((z, i) => ({ board_id: b.id, zeit: z, titel: ['', 'Heute', 'Diese Woche', 'Dieser Monat'][z], bereich: 'zeit', x: 20, y: 20 + i * 120 }))
          .concat([['team', 'Team-box', 20], ['sammel', 'Sammelbox', 150], ['notizen', 'Daten / Dauernde Notizen', 280]].map(([a, t, y]) => ({ board_id: b.id, art_id: a, titel: t, bereich: 'team', x: 20, y })));
        const r2 = await sb.from('pendenz_liste').insert(rows); if(r2.error) throw r2.error; }
      const { data: ls } = await sb.from('pendenz_liste').select('id,art_id').eq('board_id', b.id).in('art_id', ['team', 'sammel', 'notizen']);
      const f = a => ((ls || []).find(l => l.art_id === a) || {}).id || null;
      return (cache['b' + uid] = { board: b.id, team: f('team'), sammel: f('sammel'), notizen: f('notizen') });
    },
    // wohin eine neu erfasste Pendenz geht: Mitarbeiter → Heute, Büro → Sammelbox
    async ziel(sb, uid){
      const [a, b] = await Promise.all([KGPZ.ansicht(sb, uid), KGPZ.board(sb, uid)]);
      return a === 'mitarbeiter' ? { liste_id: b.team, zeit: 1, zeit_sortierung: Date.now() / 1000 } : { liste_id: b.sammel };
    },
    // Mitarbeiter: zwischen Heute und Notizen verschieben
    async verschiebe(sb, uid, pendenzId, wohin){
      const b = await KGPZ.board(sb, uid);
      const upd = wohin === 'notizen' ? { liste_id: b.notizen, zeit: null, zeit_sortierung: null } : { liste_id: b.team, zeit: 1, zeit_sortierung: Date.now() / 1000 };
      return sb.from('pendenz').update(upd).eq('id', pendenzId);
    }
  };
})();
