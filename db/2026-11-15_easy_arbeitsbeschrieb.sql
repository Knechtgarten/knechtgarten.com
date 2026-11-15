-- «Arbeitsbeschrieb» ist jetzt ein Titel im Blatt: die Zeile «- Arbeitsbeschrieb:» aus den Vorlagen-Texten entfernen
update public.easy_vorlage set hinweis_text = nullif(trim(regexp_replace(hinweis_text, '^- ?Arbeitsbeschrieb:?\s*$\n?', '', 'gmi')), '') where hinweis_text ~* 'Arbeitsbeschrieb:';
