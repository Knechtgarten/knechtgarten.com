-- KI-Quelle: ID für den Link (Offerte-ID bzw. Easybill-Dokument-ID); Suchen liefern die ID mit
alter table public.offerte_eigene_zeile add column if not exists ki_quelle_id text;
drop function if exists public.ki_offerten_zeilen_suche(text, int);
create function public.ki_offerten_zeilen_suche(begriff text, anzahl int default 25)
returns table (quelle_id text, offertnummer text, kunde text, datum date, typ text, bezeichnung text, menge numeric, einheit text, preis numeric, betrag numeric)
language sql stable security definer set search_path = public as $$
  select o.id::text, o.offertnummer, coalesce(k.name, ''), o.datum, ot.name,
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

drop function if exists public.ki_easybill_zeilen_suche(text, int);
create function public.ki_easybill_zeilen_suche(begriff text, anzahl int default 25)
returns table (quelle_id text, angebot text, datum date, kunde text, titel text, bezeichnung text, menge numeric, einheit text, preis numeric, rabatt numeric, rabatt_typ text, mwst numeric)
language sql stable security definer set search_path = public as $$
  select document_id::text, document_number, document_date, kunde, titel, bezeichnung, menge, einheit, preis, rabatt, rabatt_typ, mwst
    from easybill_angebot_zeile
   where bezeichnung ilike '%' || begriff || '%'
   order by document_date desc nulls last
   limit greatest(1, least(anzahl, 50));
$$;
revoke all on function public.ki_easybill_zeilen_suche(text, int) from public, anon;
grant execute on function public.ki_easybill_zeilen_suche(text, int) to authenticated, service_role;
select count(*) from public.ki_easybill_zeilen_suche('Carpinus', 50);
