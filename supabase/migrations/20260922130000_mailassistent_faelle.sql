-- ============================================================================
-- Mail-Assistent: neue "Fälle"-Seite (situative Regeln), Teil des Umbaus auf
-- die neue Wissensstruktur (Grundlogik / Schreibstil / Fälle / Mail-Kategorien
-- / Grunddaten / Aktionstyp). Loest Regeln aus dem Code (Personen-Rollen,
-- Dankes-Regel, Vollstaendigkeit) in einen sichtbaren, editierbaren Bereich.
--
-- tabu_liste und terminvorschlaege bleiben bewusst leer - der Inhalt liegt
-- aktuell noch im Schreibstil-Text und wird von Hand dort herausgeloest.
-- dankes_regel, personen_rollen und vollstaendigkeit werden mit dem Text
-- vorbefuellt, der heute im Code steht, damit sich am Verhalten nichts
-- aendert, sobald der Code auf diese Tabelle umgestellt wird.
-- ============================================================================

create table if not exists mailassistent_faelle_meta (
  id uuid primary key default gen_random_uuid(),
  tabu_liste text,
  dankes_regel text,
  terminvorschlaege text,
  personen_rollen text,
  vollstaendigkeit text,
  updated_at timestamptz not null default now()
);

insert into mailassistent_faelle_meta (dankes_regel, personen_rollen, vollstaendigkeit)
select
  'Übernimmt der Absender von sich aus Aufwand, Organisation oder eine Leistung für uns/unseren Kunden (z.B. Beschaffung erledigen, einen Wechsel/Besuch vor Ort selbst durchführen, Support anbieten, eine Kulanz/einen günstigeren Preis gewähren) - auch wenn das nicht wörtlich als "kostenlos"/"gratis"/"Gefallen" benannt ist, sich aber aus dem Zusammenhang erschliessen lässt - dafür ausdrücklich bedanken (z.B. "Danke, dass ihr euch um die Beschaffung/den Wechsel kümmert").',

  'Nutze die Zeile "Beteiligte Personen laut Mailkopf (Von/An/Cc)" am Anfang der eingehenden Mail (falls vorhanden), um zu bestimmen, wer zu welcher Seite gehört - jede Adresse mit @knechtgarten.ch ist unser eigenes Team, jede andere Adresse gehört zur Gegenseite (Absender selbst, dessen Kollegen, oder je nach Kontext auch Kunde/Architekt/Handwerker/weitere Partei). Nutze zusätzlich Signatur und Mailtext, um bei mehreren externen Parteien zu erkennen, wer welche Rolle hat. Bei Unklarheit über eine Rolle lieber neutral/vorsichtig formulieren statt eine Rolle zu erfinden.

Ist ein Satz erkennbar eine Anweisung/Notiz des Absenders an eine ANDERE, namentlich genannte Person (z.B. "Andrin: bitte diese 2 SIMs wechseln gehen" - eine Weisung des Absenders an dessen eigenen Kollegen, nicht an uns), betrifft das NICHT deine Antwort. Nicht kommentieren, nicht paraphrasieren und NIE behaupten, "wir"/du hättet diese Person informiert oder sie werde bei uns etwas tun. Ein im Mailtext genannter Name gehört nur dann zu unserem eigenen Team, wenn er als Knechtgarten-Mitarbeitende bekannt ist.',

  'Gehe VOR dem Schreiben die eingehende Mail Satz für Satz durch und achte dabei auf vier Arten von Punkten, nicht nur auf offensichtliche Fragen:
1. Jede Sachfrage/Bitte - beantworten oder mit Platzhalter markieren.
2. Jede persönliche/nebensächliche Bemerkung (z.B. Erwähnung von Ferien, einem Ereignis) - kurz und herzlich darauf eingehen, z.B. "Schöne Zeit noch in/an [Ort]!" bei einer Ferien-Erwähnung. Nie einfach ignorieren.
3. Übernimmt der Absender von sich aus Aufwand/Organisation für uns (siehe Dankes-Regel) - dafür bedanken.
4. Alles andere inhaltlich Wichtige.
Nichts davon darf stillschweigend fehlen. Bei mehreren Punkten entsprechend mehrere kurze Abschnitte schreiben statt alles auf 1-2 Sätze zusammenzustreichen - lieber einen Satz zu viel als zu wenig. Eine inhaltsreiche, persönliche Mail verdient eine entsprechend ausführliche, warme Antwort, keine stichwortartige Kurzabfertigung.'
where not exists (select 1 from mailassistent_faelle_meta);
