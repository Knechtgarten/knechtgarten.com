-- Formsteinmauer: Euroflex EF Einkaufspreis 54.97 (VK x 1.43 wie die meisten HG-Commerciale-Artikel),
-- 10 % Verschnitt auf Steine und deren Transport.
do $$
declare n int; m int;
begin
  update artikel set ep_lieferant = 54.97, vp_knecht = round(54.97 * 1.43, 2),
    anmerkung = 'Polymervergüteter Flex-Kleber C2-TE, 25 kg Sack, grau.'
   where artikelnummer_knecht = 'HGC_SAKRET_EUROFLEX_EF';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Euroflex-Artikel nicht gefunden'; end if;

  update ressourcenzeile rz set verschnitt_prozent = 10
    from auswahloption o, auswahlfeld f, teilschritt t, arbeitsschritt s, artikel a
   where o.id = rz.option_id and f.id = o.auswahlfeld_id and t.id = f.teilschritt_id and s.id = t.arbeitsschritt_id
     and a.id = rz.artikel_id and s.name = 'Formsteinmauer'
     and (a.artikelnummer_knecht like 'FONTAR_MS.%' or a.artikelnummer_knecht like 'FONTAR_IBERO_MACADO_%' or a.artikelnummer_knecht = 'FONTAR_L000');
  get diagnostics m = row_count;
  if m <> 24 then raise exception 'Erwartet 24 Zeilen (12 Steine + 12 Transport), geändert %', m; end if;
end $$;
