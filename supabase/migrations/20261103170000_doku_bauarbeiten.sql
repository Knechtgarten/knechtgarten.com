-- Doku-Tools: Dokumenttyp «Bauarbeiten in der Nachbarschaft» (Vorlage: Nutzers Brief Villettengässli 1, 16.02.2025).
-- Felder im Code: KGD.TYPEN.bauarbeiten (Adresse, Zeitraum optional, Arbeiten, Zusatz, Projektleiter, Vorarbeiter).
insert into doku_vorlage (ordner_id, schluessel, name, beschreibung, html, sortierung)
select o.id, 'bauarbeiten', 'Bauarbeiten in der Nachbarschaft', 'Lärm, Schmutz, kurze Wartezeiten, Kontakt Projektleiter und Vorarbeiter',
'<h2>Wir bauen in Ihrer Nachbarschaft und danken für Ihr Verständnis</h2>
<p>Sehr geehrte Nachbarinnen und Nachbarn</p>
<p>Wir dürfen <span data-f="zeitraum" class="fb fg"></span> an der Liegenschaft <span data-f="kunde_adresse" class="fb fg"></span> <span data-f="arbeiten"></span> durchführen – darauf freuen wir uns. Durch unsere Arbeiten können jedoch Lärm- und allenfalls Schmutz-Emissionen sowie beim Materialumschlag kurze Wartezeiten entstehen.</p>
<div data-f="zusatz_block"></div>
<p>Wir hoffen auf Ihr Verständnis und möchten uns schon jetzt für eventuelle Unannehmlichkeiten entschuldigen.</p>
<p>Bei Fragen oder Beschwerden rund um die Arbeiten in Ihrer Nachbarschaft wenden Sie sich bitte ohne zu zögern direkt an mich.</p>
<p>Freundliche Grüsse</p>
<div data-f="pl_block"></div><div data-f="va_block"></div>', 3
from doku_ordner o where o.name = 'Nachbarschaft'
on conflict (schluessel) do nothing;
