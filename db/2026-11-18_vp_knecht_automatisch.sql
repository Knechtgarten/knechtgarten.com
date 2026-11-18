-- VP Knecht automatisch nachrechnen (Stefan, 18.11.2026)
-- Gleiche Regel wie im Artikel-Fenster (tool-c amVpKnechtVorschlag):
--   Lieferant «Endkundenpreis = VP Knecht»: Endkundenpreis × Wechselkurs × (1 + Zuschlag %)
--   sonst:                                  EP Lieferant × Wechselkurs ÷ (1 − Marge Knecht %)
--   gerundet: bis 5 Fr. auf 0.10, bis 20 Fr. auf 0.50, darüber auf ganze Franken
-- Nur bei offenem Schloss (preis_gesperrt = false). Fehlt etwas (kein EP, keine Marge) → VP bleibt.

create or replace function public.vp_runden(n numeric) returns numeric language sql immutable as $$
  select case when n is null then null when n <= 5 then round(n / 0.1) * 0.1 when n <= 20 then round(n / 0.5) * 0.5 else round(n) end;
$$;

create or replace function public.vp_knecht_vorschlag(p_lieferant uuid, p_ep numeric, p_vp_lief numeric, p_waehrung text) returns numeric language sql stable as $$
  select public.vp_runden(case
    when d.vp_lieferant_gleich_vp_knecht then
      case when p_vp_lief > 0 then p_vp_lief * k.kurs * (1 + coalesce(d.zuschlag_prozent, 0) / 100.0) end
    else
      case when p_ep > 0 and d.minimum_marge_prozent is not null and d.minimum_marge_prozent < 100 then p_ep * k.kurs / (1 - d.minimum_marge_prozent / 100.0) end
  end)
  from public.lieferant_datenabgleich d,
       (select case when coalesce(upper(p_waehrung), 'CHF') = 'CHF' then 1
                    else coalesce((select w.kurs_zu_chf from public.wechselkurs w where w.waehrung = upper(p_waehrung)), 1) end as kurs) k
  where d.lieferant_id = p_lieferant;
$$;

-- Artikel: EP, Endkundenpreis, Währung oder Lieferant geändert (oder Schloss geöffnet) → VP neu,
-- ausser der VP wurde in derselben Änderung bewusst mitgesetzt (Artikel-Fenster). Neu erfasst ohne VP → Vorschlag.
create or replace function public.artikel_vp_auto() returns trigger language plpgsql as $$
declare v numeric;
begin
  if coalesce(new.preis_gesperrt, false) then return new; end if;
  if tg_op = 'INSERT' then
    if new.vp_knecht is not null then return new; end if;
  else
    if new.vp_knecht is distinct from old.vp_knecht then return new; end if;
    if not (new.ep_lieferant is distinct from old.ep_lieferant or new.vp_lieferant is distinct from old.vp_lieferant
            or new.waehrung is distinct from old.waehrung or new.lieferant_id is distinct from old.lieferant_id
            or (coalesce(old.preis_gesperrt, false) and not coalesce(new.preis_gesperrt, false))) then return new; end if;
  end if;
  v := public.vp_knecht_vorschlag(new.lieferant_id, new.ep_lieferant, new.vp_lieferant, new.waehrung);
  if v is not null then new.vp_knecht := v; end if;
  return new;
end $$;
drop trigger if exists artikel_vp_auto on public.artikel;
create trigger artikel_vp_auto before insert or update on public.artikel for each row execute function public.artikel_vp_auto();

-- Lieferant: Marge, Zuschlag oder Berechnungsart geändert → alle seine offenen Artikel nachrechnen
create or replace function public.lieferant_vp_auto() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.minimum_marge_prozent is distinct from old.minimum_marge_prozent or new.zuschlag_prozent is distinct from old.zuschlag_prozent
     or new.vp_lieferant_gleich_vp_knecht is distinct from old.vp_lieferant_gleich_vp_knecht then
    update public.artikel a set vp_knecht = s.v
    from (select id, public.vp_knecht_vorschlag(lieferant_id, ep_lieferant, vp_lieferant, waehrung) v from public.artikel
          where lieferant_id = new.lieferant_id and not coalesce(preis_gesperrt, false)) s
    where a.id = s.id and s.v is not null and a.vp_knecht is distinct from s.v;
  end if;
  return new;
end $$;
drop trigger if exists lieferant_vp_auto on public.lieferant_datenabgleich;
create trigger lieferant_vp_auto after update on public.lieferant_datenabgleich for each row execute function public.lieferant_vp_auto();

-- Wechselkurs geändert → offene Artikel in dieser Währung nachrechnen
create or replace function public.wechselkurs_vp_auto() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kurs_zu_chf is distinct from old.kurs_zu_chf then
    update public.artikel a set vp_knecht = s.v
    from (select id, public.vp_knecht_vorschlag(lieferant_id, ep_lieferant, vp_lieferant, waehrung) v from public.artikel
          where upper(waehrung) = upper(new.waehrung) and not coalesce(preis_gesperrt, false)) s
    where a.id = s.id and s.v is not null and a.vp_knecht is distinct from s.v;
  end if;
  return new;
end $$;
drop trigger if exists wechselkurs_vp_auto on public.wechselkurs;
create trigger wechselkurs_vp_auto after update on public.wechselkurs for each row execute function public.wechselkurs_vp_auto();
