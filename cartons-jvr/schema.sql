-- ============================================
-- CARTONS JVR - Schéma Supabase
-- Journal de suivi RH (Jaune / Vert / Rouge)
-- ============================================

-- Table principale des cartons
CREATE TABLE IF NOT EXISTS cartons_jvr (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- Salarié concerné
    salarie_id UUID NOT NULL REFERENCES users(id),
    salarie_nom TEXT NOT NULL,
    salarie_initiales TEXT,
    -- Type de carton
    type TEXT NOT NULL CHECK (type IN ('vert', 'jaune', 'rouge')),
    -- Description factuelle de l'événement
    description TEXT NOT NULL,
    -- Date de l'événement (peut différer de created_at)
    date_evenement DATE NOT NULL DEFAULT CURRENT_DATE,
    -- Auteur du carton
    auteur_id UUID NOT NULL REFERENCES users(id),
    auteur_nom TEXT NOT NULL,
    auteur_role TEXT NOT NULL,
    -- Établissement
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    -- Métadonnées
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour les requêtes fréquentes
CREATE INDEX idx_cartons_jvr_salarie ON cartons_jvr(salarie_id);
CREATE INDEX idx_cartons_jvr_etablissement ON cartons_jvr(etablissement);
CREATE INDEX idx_cartons_jvr_type ON cartons_jvr(type);
CREATE INDEX idx_cartons_jvr_date ON cartons_jvr(date_evenement DESC);

-- RLS (Row Level Security)
ALTER TABLE cartons_jvr ENABLE ROW LEVEL SECURITY;

-- Politique : lecture pour tous les authentifiés (le filtrage par rôle se fait côté app)
CREATE POLICY "cartons_jvr_select" ON cartons_jvr
    FOR SELECT USING (true);

-- Politique : insertion pour tous les authentifiés
CREATE POLICY "cartons_jvr_insert" ON cartons_jvr
    FOR INSERT WITH CHECK (true);

-- Politique : mise à jour pour tous les authentifiés
CREATE POLICY "cartons_jvr_update" ON cartons_jvr
    FOR UPDATE USING (true);

-- Politique : suppression pour tous les authentifiés
CREATE POLICY "cartons_jvr_delete" ON cartons_jvr
    FOR DELETE USING (true);

-- Trigger mise à jour updated_at
CREATE OR REPLACE FUNCTION update_cartons_jvr_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cartons_jvr_updated_at
    BEFORE UPDATE ON cartons_jvr
    FOR EACH ROW
    EXECUTE FUNCTION update_cartons_jvr_updated_at();
