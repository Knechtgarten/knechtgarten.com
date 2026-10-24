-- Nachschlagewerk: «Zuständig» heisst «Fahrer» und wird aus der Personenliste des Einsatzplaners gewählt.
-- Bestehende Vornamen werden zum vollen Namen, wenn genau eine aktive Person so heisst. Alles andere bleibt, wie es ist.
update public.wissen_exemplar x set zustaendig = p.name
from (select split_part(name, ' ', 1) vorname, min(name) name from public.planer_person where aktiv group by 1 having count(*) = 1) p
where x.zustaendig = p.vorname;
