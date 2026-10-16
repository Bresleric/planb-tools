-- ============================================================
-- Migration — Briefing : bloc Repas perso
-- Projet Supabase : dzrherfavgiuygnimtux
-- Idempotente : re-executable sans erreur.
-- Pas de nouvelle table -> pas de policy a creer, la colonne
-- herite de la policy pbt_session de briefings.
-- STATUT : APPLIQUEE via MCP le 16/10/2026.
-- ============================================================

ALTER TABLE briefings
  ADD COLUMN IF NOT EXISTS repas_perso jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Format attendu :
-- [{ "plat": "Boeuf bourguignon", "date_production": "2026-10-15",
--    "stock": 4, "unite": "portions" }]

-- Verification post-migration :
-- SELECT column_name, data_type FROM information_schema.columns
--   WHERE table_name = 'briefings' AND column_name = 'repas_perso';
