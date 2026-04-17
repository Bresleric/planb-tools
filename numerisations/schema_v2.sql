-- =============================================
-- NUMERISATIONS V2 : Mode Réception + Étiquettes
-- À exécuter dans Supabase SQL Editor
-- =============================================

-- 1. Table sessions de réception
-- Une session = une livraison = un fournisseur + un N° pièce
CREATE TABLE IF NOT EXISTS reception_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    fournisseur_id UUID,
    fournisseur_nom TEXT NOT NULL,
    type_piece TEXT NOT NULL CHECK (type_piece IN ('facture', 'bl')),
    reference_piece TEXT,          -- N° facture ou BL
    nb_etiquettes INT DEFAULT 0,
    statut TEXT DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'traitement', 'termine', 'erreur')),
    -- Utilisateur
    user_id UUID,
    user_nom TEXT,
    user_initiales TEXT,
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Table données extraites des étiquettes
-- Chaque étiquette scannée = 1 ligne avec maximum de données
CREATE TABLE IF NOT EXISTS etiquettes_data (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    -- Liens
    session_id UUID REFERENCES reception_sessions(id) ON DELETE CASCADE,
    page_id UUID REFERENCES numerisations_pages(id) ON DELETE SET NULL,
    -- Photo originale
    photo_data TEXT,               -- base64 de la photo
    photo_thumb TEXT,              -- miniature base64
    texte_ocr TEXT,                -- Texte brut OCR
    -- Identification produit
    produit TEXT,                  -- Nom du produit (ex: "JAMBON CUIT en tranches")
    code_article TEXT,             -- Code article fournisseur (ex: "062300")
    categorie TEXT,                -- Catégorie détectée (viande, charcuterie, fromage, etc.)
    -- Traçabilité
    lot TEXT,                      -- Numéro de lot
    dlc DATE,                      -- Date limite de consommation
    ddm DATE,                      -- Date de durabilité minimale (DLUO)
    date_fabrication DATE,
    date_emballage DATE,
    date_abattage DATE,
    -- Poids
    poids_net_kg NUMERIC(8,3),
    tare_kg NUMERIC(8,3),
    -- Conservation
    temp_min NUMERIC(4,1),
    temp_max NUMERIC(4,1),
    -- Composition
    ingredients TEXT,              -- Texte complet ingrédients
    allergenes TEXT[],             -- Liste des allergènes détectés
    -- Nutrition (JSONB flexible)
    nutrition JSONB,
    -- ex: {"energie_kj":465,"energie_kcal":110,"lipides":2.8,"satures":0.96,
    --       "glucides":0.2,"sucres":0.5,"proteines":21.1,"sel":1.59}
    -- Origine / Identification
    origine TEXT,                  -- Pays d'origine
    estampille TEXT,               -- Estampille sanitaire (FR 68-331-001 CE)
    fabricant TEXT,                -- Nom fabricant si différent du fournisseur
    code_barres TEXT,              -- EAN / code-barres
    -- Méta OCR
    confiance_ocr INT DEFAULT 0,  -- Score confiance 0-100
    statut TEXT DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'extrait', 'verifie', 'erreur')),
    observation TEXT,
    -- Contexte
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Ajouter session_id aux numerisations existantes (optionnel, pour lier)
ALTER TABLE numerisations ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES reception_sessions(id) ON DELETE SET NULL;

-- 4. Index pour performance
CREATE INDEX IF NOT EXISTS idx_reception_sessions_etab_date ON reception_sessions(etablissement, date DESC);
CREATE INDEX IF NOT EXISTS idx_reception_sessions_statut ON reception_sessions(statut);
CREATE INDEX IF NOT EXISTS idx_etiquettes_session ON etiquettes_data(session_id);
CREATE INDEX IF NOT EXISTS idx_etiquettes_dlc ON etiquettes_data(dlc);
CREATE INDEX IF NOT EXISTS idx_etiquettes_produit ON etiquettes_data(produit);
CREATE INDEX IF NOT EXISTS idx_etiquettes_lot ON etiquettes_data(lot);
CREATE INDEX IF NOT EXISTS idx_etiquettes_etab ON etiquettes_data(etablissement);
CREATE INDEX IF NOT EXISTS idx_etiquettes_statut ON etiquettes_data(statut);

-- 5. RLS (même pattern que les autres tables)
ALTER TABLE reception_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE etiquettes_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_all_reception_sessions" ON reception_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all_etiquettes_data" ON etiquettes_data FOR ALL USING (true) WITH CHECK (true);

-- 6. Fonction pour mettre à jour le compteur d'étiquettes
CREATE OR REPLACE FUNCTION update_reception_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE reception_sessions SET nb_etiquettes = (
            SELECT COUNT(*) FROM etiquettes_data WHERE session_id = NEW.session_id
        ), updated_at = NOW() WHERE id = NEW.session_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE reception_sessions SET nb_etiquettes = (
            SELECT COUNT(*) FROM etiquettes_data WHERE session_id = OLD.session_id
        ), updated_at = NOW() WHERE id = OLD.session_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_reception_count
AFTER INSERT OR DELETE ON etiquettes_data
FOR EACH ROW EXECUTE FUNCTION update_reception_count();
