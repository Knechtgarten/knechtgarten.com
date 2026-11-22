-- Maschinen: Kategorie «Geräte & Werkzeug» heisst «Kleingeräte & Werkzeug» (Bohrmaschinen, Motorsägen …, nicht im Planer);
-- leere Kategorie «Pooltechnik» und der «Testeintrag» werden entfernt.
update wissen_kategorie set name = 'Kleingeräte & Werkzeug' where name = 'Geräte & Werkzeug' and art = 'geraet';
delete from wissen_exemplar where eintrag_id = '69c1285d-9df4-4781-879a-9496ca685e28';
delete from wissen_eintrag where id = '69c1285d-9df4-4781-879a-9496ca685e28' and titel = 'Testeintrag';
delete from wissen_kategorie k where k.name = 'Pooltechnik' and not exists (select 1 from wissen_eintrag e where e.kategorie_id = k.id);
select string_agg(name, ' | ' order by sortierung) as kategorien from wissen_kategorie where art = 'geraet';
