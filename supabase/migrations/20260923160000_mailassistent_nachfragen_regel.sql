-- Mail-Assistent: Verhalten festlegen, wenn keine Vorlage/kein Zweig passt
-- oder eine Angabe fehlt - kurzer Verweis-Punkt in Grundlogik (Ablauf-
-- Uebersicht) + ausfuehrliche Regel bei den Regeln (gleiche Kategorie wie
-- Dankes-Regel/Vollstaendigkeit). Faustregel: fehlt nur ein Detail ->
-- Platzhalter im Text, fehlt eine grundsaetzliche Richtung -> Rueckfrage,
-- alles andere -> selbst schreiben (Entwurf wird vor dem Versenden eh noch
-- geprueft, darum nicht vorschnell nachfragen).
do $$
declare
  v_grundlogik_start int;
  v_regel_start int;
begin
  select coalesce(max(reihenfolge), -1) + 1 into v_grundlogik_start from mailassistent_grundlogik_abschnitt;
  select coalesce(max(reihenfolge), -1) + 1 into v_regel_start from mailassistent_faelle_abschnitt;

  insert into mailassistent_grundlogik_abschnitt (titel, inhalt, reihenfolge) values
  ('7. Wenn nichts passt',
   'Passt keine Vorlage/kein Zweig zur eingehenden Mail: Fehlt nur eine einzelne Angabe (Zahl, Name, interner Entscheid), die nur wir wissen - Platzhalter im Text setzen, nicht nachfragen. Ist die Anfrage inhaltlich klar, es gibt aber keine Vorlage dafür - selbst einen passenden Text schreiben (Auffangfall), nach Schreibstil und Regeln. Nur wenn die Antwort von einer grundsätzlichen Weichenstellung abhängt, die stark unterschiedliche Antworten ergäbe, UND wirklich unklar ist, wohin es geht - dann erst eine Rückfrage/Auswahl anbieten. Details dazu bei den Regeln.',
   v_grundlogik_start);

  insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge) values
  ('Nachfragen vs. selbst entscheiden',
   'Wenn keine passende Vorlage oder kein passender Zweig gefunden wird, oder eine Information fehlt:
- Fehlt nur eine einzelne konkrete Angabe (z.B. eine Zahl, ein Name, ein interner Entscheid), die nur das Team wissen kann: einen Platzhalter im Text setzen (z.B. [Antwort: ...]), NICHT extra nachfragen. Der Mitarbeiter füllt das vor dem Versenden selbst aus.
- Ist die Anfrage inhaltlich klar, passt aber keine bestehende Vorlage: selbst einen passenden, kurzen Text schreiben (Schreibstil und diese Regeln gelten dabei genauso).
- Nur wenn die richtige Antwort von einer grundsätzlichen Weichenstellung abhängt, die zu stark unterschiedlichen Mails führen würde (z.B. zusagen oder absagen), UND wirklich unklar ist, welche Richtung zutrifft: eine Rückfrage/Auswahl an den Mitarbeiter stellen statt zu raten.
- Grundsätzlich gilt: jede generierte Mail ist nur ein Entwurf, der vor dem Absenden noch geprüft wird - eine unnötige Rückfrage kostet nur zusätzlichen Aufwand. Im Zweifel lieber selbst einen sinnvollen Text schreiben, als vorschnell nachzufragen.',
   v_regel_start);
end $$;
