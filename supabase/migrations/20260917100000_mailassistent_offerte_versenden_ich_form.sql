-- ============================================================================
-- Mail-Assistent: Vorlage "Offerte versenden" enthielt noch zwei Varianten im
-- Inhalt (eine "ich"- und eine "wir"-Formulierung, durch die alten Labels
-- "(ich)" / "### Offerte (wir)" getrennt) - dadurch landete beim Einfuegen
-- der ganze Text mit beiden Varianten in der Mail. Ab jetzt nur noch die
-- "ich"-Form, ohne die Labels.
-- ============================================================================

update mailassistent_vorlage
set inhalt = 'Guten Tag

Gerne sende ich Ihnen im Anhang die Offerten zu den besprochenen Gartenarbeiten.

Die Offerten orientieren sich an unserem Austausch und den aktuell gewünschten Arbeiten.

Ich würde mich sehr freuen, diese Arbeiten für Sie ausführen zu dürfen.

Sollten sich beim Durchsehen Fragen ergeben oder falls sich Wünsche ändern, sei es inhaltlich oder im Hinblick auf das Budget, passe ich die Offerten jederzeit gerne und kostenlos an.

Gerne bespreche ich offene Punkte auch telefonisch oder bei einem persönlichen Termin. Ebenso können wir einen Termin bei uns im Geschäft vereinbaren, um verschiedene Muster der Bauteile gemeinsam anzuschauen.

Ich freue mich auf Ihre Rückmeldung und stehe Ihnen gerne zur Verfügung.

Meine Kontaktdaten finden Sie unten in der Signatur.

Freundliche Grüsse'
where titel = 'Offerte versenden';
