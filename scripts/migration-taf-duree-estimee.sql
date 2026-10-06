-- ============================================================================
-- Migration : duree estimee manuelle des taches TAF (06/10/2026)
-- APPLIQUEE via MCP le 06/10/2026 — fichier conserve pour trace.
--
-- Prevision du temps par tache, ordre de priorite :
--   1. duree_estimee_minutes saisie a la main (tache ou recurrence)
--   2. mediane des chronos des 120 derniers jours (meme intitule)
--   3. temps de preparation de la fiche technique liee
-- ============================================================================

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS duree_estimee_minutes integer;
ALTER TABLE taches_recurrentes ADD COLUMN IF NOT EXISTS duree_estimee_minutes integer;

-- Verification :
-- SELECT table_name, column_name FROM information_schema.columns
--   WHERE column_name = 'duree_estimee_minutes';  -- attendu : 2 lignes
