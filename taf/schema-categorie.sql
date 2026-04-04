-- ============================================================
-- TAF Module - Migration : ajout du champ "categorie"
-- Valeurs : Production, Mise en Place, Nettoyage, Rangements
-- À exécuter dans Supabase SQL Editor AVANT le déploiement
-- ============================================================

-- 1. Ajouter le champ categorie sur la table tasks
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS categorie TEXT;

-- 2. (Optionnel) Contrainte de valeurs autorisées
-- Commenté par défaut pour ne pas casser les anciennes tâches sans catégorie
-- ALTER TABLE tasks ADD CONSTRAINT tasks_categorie_chk
--   CHECK (categorie IS NULL OR categorie IN ('Production', 'Mise en Place', 'Nettoyage', 'Rangements'));

-- 3. Index pour filtrer/rechercher par catégorie
CREATE INDEX IF NOT EXISTS idx_tasks_categorie
    ON tasks(categorie, etablissement);

-- 4. Ajouter aussi le champ sur les tâches récurrentes (propagé aux tâches générées)
ALTER TABLE taches_recurrentes ADD COLUMN IF NOT EXISTS categorie TEXT;

-- 5. Vérification
-- SELECT column_name, data_type FROM information_schema.columns
--   WHERE table_name = 'tasks' AND column_name = 'categorie';
