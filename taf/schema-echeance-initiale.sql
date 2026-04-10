-- Migration : report automatique des tâches en retard sur Jour J
-- Ajoute une colonne pour mémoriser l'échéance d'origine avant report
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS echeance_initiale DATE;

-- Index pour accélérer la requête de report (recherche des tâches non faites en retard)
CREATE INDEX IF NOT EXISTS idx_tasks_report_late
  ON tasks (etablissement, echeance)
  WHERE fait_par_id IS NULL;
