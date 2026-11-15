-- Für die KI-Offerte: Zeilen aus alten Offerten (kosten_snapshot) nach Stichwort suchen
create or replace function public.ki_offerten_zeilen_suche(begriff text, anzahl int default 25)
returns table (offertnummer text, kunde text, datum date, typ text, bezeichnung text, menge numeric, einheit text, preis numeric, betrag numeric)
language sql stable security definer set search_path = public as $$
  select o.offertnummer, coalesce(k.name, ''), o.datum, ot.name,
         z->>'bezeichnung', nullif(z->>'menge','')::numeric, z->>'einheit', nullif(z->>'preis','')::numeric, nullif(z->>'betrag','')::numeric
    from offerte o
    left join kunde k on k.id = o.kunde_id
    left join offertentyp ot on ot.id = o.offertentyp_id
    cross join lateral jsonb_array_elements(coalesce(o.kosten_snapshot->'gruppen', '[]'::jsonb)) g
    cross join lateral jsonb_array_elements(coalesce(g->'zeilen', '[]'::jsonb)) z
   where (z->>'bezeichnung') ilike '%' || begriff || '%'
     and coalesce((z->>'geloescht')::boolean, false) = false
   order by o.datum desc nulls last
   limit greatest(1, least(anzahl, 50));
$$;
revoke all on function public.ki_offerten_zeilen_suche(text, int) from public, anon;
grant execute on function public.ki_offerten_zeilen_suche(text, int) to authenticated, service_role;
