-- ============================================================================
-- Mail-Assistent: Dropdown-Optionen pro Zusatzfenster-Spalte.
--
-- Zusatzspalten (z.B. "Farbe", "Erdspiess") werden in Gmail immer als
-- Dropdown mit fest hinterlegten Werten abgefuellt, nicht als Freitext.
-- ============================================================================

create table mailassistent_zusatzfenster_spalte_option (
  id uuid primary key default gen_random_uuid(),
  spalte_id uuid not null references mailassistent_zusatzfenster_spalte(id) on delete cascade,
  wert text not null,
  reihenfolge int not null default 0
);

alter table mailassistent_zusatzfenster_spalte_option enable row level security;
create policy mailassistent_zusatzfenster_spalte_option_buero_admin
  on mailassistent_zusatzfenster_spalte_option for all
  using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
