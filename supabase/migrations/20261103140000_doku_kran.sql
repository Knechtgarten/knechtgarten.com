-- Doku-Tools: neuer Dokumenttyp «Kraneinsatz» (Ordner Nachbarschaft), gleich aufgebaut wie Helikoptereinsatz.
-- Felder/Angaben im Code: KGD.TYPEN.kran (Adresse, Datum/Zeit, Zusatz, Projektleiter, Vorarbeiter).
insert into doku_vorlage (ordner_id, schluessel, name, beschreibung, html, sortierung)
select o.id, 'kran', 'Kraneinsatz', 'Info für die Anwohner: Datum, Zeit, Durchfahrt gesperrt',
'<h2>Kraneinsatz in Ihrer Nachbarschaft</h2>
<p>Sehr geehrte Anwohnerinnen und Anwohner</p>
<p>Am <span data-f="datum"></span> <span data-f="zeit"></span> heben wir bei der Liegenschaft <span data-f="kunde_adresse"></span> mit einem Lastwagenkran Material in den Garten. Während dieser Zeit ist die Durchfahrt nicht möglich.</p>
<div data-f="zusatz_block"></div>
<p>Wir bitten Sie um Verständnis und danken Ihnen bereits dafür. Falls Sie Fragen haben, dürfen Sie sich gerne direkt bei mir melden.</p>
<p>Freundliche Grüsse</p>
<div data-f="pl_block"></div><div data-f="va_block"></div>', 2
from doku_ordner o where o.name = 'Nachbarschaft'
on conflict (schluessel) do nothing;
