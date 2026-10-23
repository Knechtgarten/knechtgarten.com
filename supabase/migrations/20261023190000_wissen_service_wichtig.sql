-- ============================================================================
-- Wissen & Geräte: Service-Arbeit «wichtig» (z. B. Hochdruckreiniger vor dem Frost
-- einwintern – Auslassen kostet viel). Im Einsatzplaner andere Farbe; nicht erledigt
-- wandert sie weiter, bis sie abgehakt ist. Normale Arbeiten nur noch 4 Wochen.
-- ============================================================================
alter table wissen_service add column if not exists wichtig boolean not null default false;
