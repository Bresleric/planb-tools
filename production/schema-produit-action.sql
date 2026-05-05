-- =============================================================================
-- predefined_tasks : décomposition en produit + action
-- =============================================================================
-- Date : 2026-05-04
-- Ajout additif : on garde la colonne `nom` (référencée par le code existant
-- et par le matching tasks.tache = predefined_tasks.nom). On ajoute juste
-- 2 colonnes pour la nouvelle nomenclature structurée.

ALTER TABLE public.predefined_tasks
  ADD COLUMN IF NOT EXISTS produit TEXT,
  ADD COLUMN IF NOT EXISTS action  TEXT;

CREATE INDEX IF NOT EXISTS idx_predefined_tasks_produit ON public.predefined_tasks (produit) WHERE produit IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_predefined_tasks_action  ON public.predefined_tasks (action)  WHERE action  IS NOT NULL;

COMMENT ON COLUMN public.predefined_tasks.produit IS 'Composante "produit" de la tâche (ex: Carottes, Œufs, Paleron). Le nom reste la source de vérité pour le matching avec tasks.';
COMMENT ON COLUMN public.predefined_tasks.action  IS 'Composante "action" de la tâche (ex: Éplucher, Tailler en cube, Sous-vide, Cuire).';
