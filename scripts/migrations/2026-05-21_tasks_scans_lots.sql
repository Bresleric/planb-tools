-- ============================================================
-- Phase B — Continuité TAF → Production
-- Colonne de persistance des étiquettes scannées sur une tâche
-- ============================================================
-- Les étiquettes scannées dans le module TAF (ingrédients principaux)
-- doivent survivre jusqu'à la validation de la production, y compris
-- si le scan et la validation se font sur 2 iPads différents.
--
-- Structure du JSONB scans_lots :
--   {
--     "<ingredient_id>": {
--       "scan_tracabilite_id": "uuid",
--       "article_id": "uuid",
--       "article_id_attendu": "uuid|null",
--       "nom_attendu": "texte|null",
--       "produit": "texte",
--       "lot": "texte",
--       "dlc": "date|null",
--       "fabricant": "texte|null",
--       "poids_net_kg": nombre|null,
--       "timestamp": "iso"
--     },
--     ...
--   }
-- Clé = id de la ligne fiche_ingredients (1 scan par ingrédient principal).
-- ============================================================

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS scans_lots jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN tasks.scans_lots IS
  'Phase B — étiquettes scannées pour les ingrédients principaux, '
  'mémorisées entre le scan (module TAF) et la validation de la production. '
  'Clé = fiche_ingredients.id, valeur = infos du scan (lot, dlc, article...).';

-- Vérification
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'tasks' AND column_name = 'scans_lots';
