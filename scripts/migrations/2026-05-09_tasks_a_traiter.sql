-- ====================================================================
-- Migration — 2026-05-09 — tasks.a_traiter
--
-- Ajoute un drapeau booléen sur tasks pour identifier les tâches créées
-- via le chemin 'À créer' (qui ne matchent aucune fiche technique au
-- moment de la création) et qui doivent être triées par un admin :
--   - soit promues en fiche technique
--   - soit liées à une fiche existante (typo, synonyme)
--   - soit ignorées (la tâche reste fonctionnelle mais ne crée pas de référence)
--
-- Sécurité : DEFAULT false NOT NULL pour ne pas casser les insertions
-- existantes. Index partiel pour requêtes admin rapides.
-- ====================================================================

BEGIN;

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS a_traiter BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.tasks.a_traiter IS
  'true = tâche créée via le chemin "À créer" (libellé libre, pas de fiche technique connue). Doit être triée par un admin.';

CREATE INDEX IF NOT EXISTS idx_tasks_a_traiter
  ON public.tasks (a_traiter)
  WHERE a_traiter = true;

COMMIT;

-- ===========================
-- Validation
-- ===========================
-- Doit retourner 0 (aucune tâche existante marquée à traiter)
-- SELECT COUNT(*) FROM tasks WHERE a_traiter = true;
-- Doit lister la colonne
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'tasks' AND column_name = 'a_traiter';
