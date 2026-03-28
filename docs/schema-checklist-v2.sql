-- ============================================================
-- PlanB Tools - Check-Lists Module v2
-- Schéma de base de données - Modifications Supabase
-- Date : 28 mars 2026
-- ============================================================

-- 1. NOUVELLE TABLE : services
-- Utilisée pour définir les plages horaires des services (midi/soir)
-- Réutilisable par d'autres modules (pointages, briefings, etc.)
CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT NOT NULL,
    heure_debut TIME NOT NULL,
    heure_fin TIME NOT NULL,
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    actif BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Données initiales services
INSERT INTO services (nom, heure_debut, heure_fin, etablissement) VALUES
    ('Midi', '09:00', '15:30', 'freddy'),
    ('Soir', '17:00', '23:30', 'freddy'),
    ('Midi', '09:00', '15:30', 'liesel'),
    ('Soir', '17:00', '23:30', 'liesel');

-- 2. MODIFICATIONS TABLE : checklists
-- Ajout des colonnes equipe, service, jours_semaine, jour_mois
ALTER TABLE checklists ADD COLUMN IF NOT EXISTS equipe TEXT DEFAULT 'tous';
ALTER TABLE checklists ADD COLUMN IF NOT EXISTS service TEXT DEFAULT 'tous';
ALTER TABLE checklists ADD COLUMN IF NOT EXISTS jours_semaine INT[] DEFAULT NULL;
ALTER TABLE checklists ADD COLUMN IF NOT EXISTS jour_mois INT[] DEFAULT NULL;

-- 3. MODIFICATIONS TABLE : checklist_items
-- Ajout de la durée indicative en minutes
ALTER TABLE checklist_items ADD COLUMN IF NOT EXISTS duree_indicative INT DEFAULT NULL;

-- 4. MODIFICATIONS TABLE : checklist_completions
-- Ajout du champ observation
ALTER TABLE checklist_completions ADD COLUMN IF NOT EXISTS observation TEXT DEFAULT NULL;

-- 5. NOUVELLE TABLE : checklist_validations
-- Validation par les managers/admins après achèvement d'une checklist
CREATE TABLE IF NOT EXISTS checklist_validations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    checklist_id UUID NOT NULL REFERENCES checklists(id),
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    periode TEXT NOT NULL,
    service TEXT,
    statut TEXT NOT NULL CHECK (statut IN ('ok', 'probleme')),
    commentaire TEXT,
    valide_par_id UUID,
    valide_par_nom TEXT,
    valide_par_initiales TEXT,
    valide_at TIMESTAMPTZ DEFAULT now()
);

-- Index pour les performances
CREATE INDEX IF NOT EXISTS idx_checklist_validations_lookup
    ON checklist_validations(checklist_id, etablissement, periode);

CREATE INDEX IF NOT EXISTS idx_checklists_etab_actif
    ON checklists(etablissement, actif);

CREATE INDEX IF NOT EXISTS idx_checklist_completions_lookup
    ON checklist_completions(checklist_id, etablissement, periode, service);

-- 6. RLS (Row Level Security) - Autoriser accès via anon key
-- Note: les policies existantes pour checklists/items/completions restent en place
-- Ajouter les policies pour les nouvelles tables

ALTER TABLE services ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for services" ON services FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE checklist_validations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for checklist_validations" ON checklist_validations FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- FIN DU SCRIPT
-- ============================================================
