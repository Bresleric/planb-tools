-- ============================================================
-- TAF Module - Schema SQL
-- Migration depuis Kitchen TAF + nouvelles fonctionnalités
-- À exécuter dans Supabase SQL Editor AVANT le déploiement
-- ============================================================

-- 1. Migration table tasks : renommer equipe → creneau, ajouter nouveaux champs
-- ============================================================

-- Renommer le champ equipe existant en creneau (il contient Matin/Midi/Soir)
ALTER TABLE tasks RENAME COLUMN equipe TO creneau;

-- Ajouter le champ equipe (l'équipe réelle : salle, cuisine, plonge, autre)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS equipe TEXT DEFAULT 'cuisine';

-- Ajouter les champs d'attribution
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS attribue_a_id UUID;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS attribue_a_nom TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS attribue_a_initiales TEXT;

-- Ajouter un lien vers la récurrence source (NULL si tâche manuelle)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS recurrence_id UUID;

-- Mettre à jour les anciennes tâches : equipe = 'cuisine' par défaut (puisque c'était Kitchen TAF)
UPDATE tasks SET equipe = 'cuisine' WHERE equipe IS NULL OR equipe = 'cuisine';

-- 2. Table des tâches récurrentes
-- ============================================================
CREATE TABLE IF NOT EXISTS taches_recurrentes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT NOT NULL,
    equipe TEXT NOT NULL DEFAULT 'cuisine',
    creneau TEXT DEFAULT 'Matin',
    priorite INTEGER DEFAULT 3,
    observation TEXT,

    -- Configuration de la récurrence
    -- Types : 'quotidien', 'tous_x_jours', 'jours_semaine', 'jours_mois'
    frequence_type TEXT NOT NULL DEFAULT 'quotidien',
    -- Pour 'tous_x_jours' : nombre de jours (ex: 2 = tous les 2 jours)
    -- Pour 'jours_semaine' : JSON array des jours [1,2,3,4,5] (1=lundi, 7=dimanche)
    -- Pour 'jours_mois' : JSON array des jours [1,15,28]
    -- Pour 'quotidien' : NULL
    frequence_valeur JSONB,

    -- Date de début de la récurrence
    date_debut DATE NOT NULL DEFAULT CURRENT_DATE,
    -- Date de fin optionnelle
    date_fin DATE,

    -- Dernière date pour laquelle les tâches ont été générées
    derniere_generation DATE,

    etablissement TEXT NOT NULL,
    actif BOOLEAN DEFAULT true,
    cree_par_id UUID,
    cree_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index pour la génération rapide
CREATE INDEX IF NOT EXISTS idx_recurrentes_etab_actif
    ON taches_recurrentes(etablissement, actif);

-- Index pour les tâches par date et établissement
CREATE INDEX IF NOT EXISTS idx_tasks_echeance_etab
    ON tasks(echeance, etablissement);

-- Index pour les tâches par équipe
CREATE INDEX IF NOT EXISTS idx_tasks_equipe
    ON tasks(equipe);

-- 3. Ajouter equipe dans predefined_tasks si pas déjà présent
-- ============================================================
ALTER TABLE predefined_tasks ADD COLUMN IF NOT EXISTS equipe TEXT DEFAULT 'cuisine';
ALTER TABLE predefined_tasks ADD COLUMN IF NOT EXISTS creneau TEXT DEFAULT 'Matin';

-- 4. RLS (Row Level Security) - optionnel mais recommandé
-- ============================================================
-- ALTER TABLE taches_recurrentes ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all for anon" ON taches_recurrentes FOR ALL USING (true);

-- 5. Vérification
-- ============================================================
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'tasks' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'taches_recurrentes' ORDER BY ordinal_position;
