-- ============================================================
-- TAF Module - Ajout du chronomètre par tâche
-- À exécuter dans Supabase SQL Editor (projet dzrherfavgiuygnimtux)
-- AVANT de déployer la nouvelle version de taf/index.html
-- ============================================================

-- Horodatage du démarrage du chrono (NULL = non démarré)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS date_debut_execution TIMESTAMPTZ;

-- Qui a démarré le chrono (utile pour audit, peut différer du valideur)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS debut_par_id UUID;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS debut_par_initiales TEXT;

-- Durée totale en secondes, calculée à la validation de la tâche
-- (NULL si la tâche n'a pas été chronométrée)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS duree_secondes INTEGER;

-- Vérification
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'tasks'
--   AND column_name IN ('date_debut_execution','debut_par_id','debut_par_initiales','duree_secondes');
