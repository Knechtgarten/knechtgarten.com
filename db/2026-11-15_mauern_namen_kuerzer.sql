-- Konfigurator-Balken einzeilig (Mauern + Teich-Natursteinmauer): Teilschritt- und Auswahlfeld-Namen kürzen
update public.teilschritt set name = 'Mauer wechselschichtig' where name = 'Natursteinmauer Plasselb wechselschichtig';
update public.teilschritt set name = 'Mauer geschichtet' where name = 'Natursteinmauer geschichtet in Blöcken';
update public.teilschritt set name = 'Polengranit Grossmengen franko' where name = 'Polengranit Grossmengen franko geliefert';
update public.teilschritt set name = 'Polengranit Kleinmengen' where name = 'Polengranit Kleinmengen ab Lager Liestal';
update public.auswahlfeld set name = 'Mauer wechselschichtig' where name = 'Natursteinmauer Plasselb wechselschichtig';
update public.auswahlfeld set name = 'Mauer geschichtet' where name = 'Natursteinmauer geschichtet in Blöcken';
update public.auswahlfeld set name = 'Polengranit Grossmengen franko' where name = 'Polengranit Grossmengen franko geliefert';
update public.auswahlfeld set name = 'Polengranit Kleinmengen' where name = 'Polengranit Kleinmengen ab Lager Liestal';
