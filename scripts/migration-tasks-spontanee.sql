-- ============================================================
-- Migration : tasks.spontanee
-- Ajoute un drapeau pour les tâches créées à la volée par le
-- module Production (production directe sans TAF planifié).
-- Ces tâches sont invisibles dans le TAF mais conservent toute
-- la mécanique (chrono, stats par personne, scans_lots, etc.).
-- À exécuter dans Supabase → SQL Editor.
-- ============================================================

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS spontanee BOOLEAN DEFAULT FALSE;

-- Backfill : aucune ligne existante n'est spontanée
UPDATE tasks SET spontanee = FALSE WHERE spontanee IS NULL;

-- Index partiel : la grande majorité des tasks restera FALSE,
-- donc on n'indexe que les TRUE (lookup rapide côté Production).
CREATE INDEX IF NOT EXISTS idx_tasks_spontanee
  ON tasks(spontanee) WHERE spontanee = TRUE;

-- Vérification
SELECT
  COUNT(*) FILTER (WHERE spontanee = TRUE)  AS nb_spontanees,
  COUNT(*) FILTER (WHERE spontanee = FALSE) AS nb_planifiees,
  COUNT(*) FILTER (WHERE spontanee IS NULL) AS nb_null
FROM tasks;
