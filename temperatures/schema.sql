-- ============================================================
-- Module Temperatures Frigos - Schema SQL
-- Suivi HACCP des temperatures des refrigerateurs
-- A executer dans Supabase SQL Editor AVANT le deploiement
-- ============================================================

-- 1. Table des frigos (configuration par etablissement)
-- ============================================================
CREATE TABLE IF NOT EXISTS temp_frigos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT NOT NULL,
    categorie TEXT NOT NULL DEFAULT 'CUISINE',  -- CAVE, CUISINE, LABO, etc.
    temp_min NUMERIC(5,1) NOT NULL DEFAULT 0,
    temp_max NUMERIC(5,1) NOT NULL DEFAULT 5,
    temp_limite NUMERIC(5,1) NOT NULL DEFAULT 7,  -- seuil critique HACCP
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    actif BOOLEAN DEFAULT true,
    ordre INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_temp_frigos_etab ON temp_frigos(etablissement, actif);

-- 2. Table des releves de temperature
-- ============================================================
CREATE TABLE IF NOT EXISTS temp_releves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    frigo_id UUID NOT NULL REFERENCES temp_frigos(id),
    frigo_nom TEXT NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    temperature NUMERIC(5,1) NOT NULL,
    hors_norme BOOLEAN DEFAULT false,
    photo_requise BOOLEAN DEFAULT false,
    photo_data TEXT,  -- base64 de la photo (NULL si pas de photo)
    est_controle_1h BOOLEAN DEFAULT false,  -- true si c'est un re-controle apres 1h
    releve_parent_id UUID REFERENCES temp_releves(id),  -- lien vers le releve initial hors norme
    observation TEXT,
    user_id UUID NOT NULL,
    user_nom TEXT NOT NULL,
    user_initiales TEXT,
    etablissement TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(frigo_id, date, est_controle_1h, releve_parent_id)
);

-- Index pour requetes frequentes
CREATE INDEX IF NOT EXISTS idx_temp_releves_date ON temp_releves(date, etablissement);
CREATE INDEX IF NOT EXISTS idx_temp_releves_frigo ON temp_releves(frigo_id, date);
CREATE INDEX IF NOT EXISTS idx_temp_releves_hors_norme ON temp_releves(hors_norme, date) WHERE hors_norme = true;

-- 3. Donnees initiales - Frigos Freddy (d'apres la liste fournie)
-- ============================================================
INSERT INTO temp_frigos (nom, categorie, temp_min, temp_max, temp_limite, etablissement, ordre) VALUES
('CF POSITIVE', 'CAVE', 0, 5, 7, 'freddy', 1),
('CONGEL CAVE BOISSON', 'CAVE', -25, -18, -15, 'freddy', 2),
('CONGELATEUR BAR/GLACES', 'CUISINE', -25, -18, -15, 'freddy', 3),
('CUISINE DROITE', 'CUISINE', 0, 2, 4, 'freddy', 4),
('CUISINE GAUCHE', 'CUISINE', 0, 2, 4, 'freddy', 5),
('FRIGO 1 - EPICERIE', 'LABO', 0, 5, 6, 'freddy', 6),
('FRIGO 2 - LEGUMES', 'LABO', 0, 4, 6, 'freddy', 7),
('FRIGO 3 - SALLE', 'LABO', 0, 5, 7, 'freddy', 8),
('TABLE REFRIGEREE DROITE', 'LABO', 0, 2, 4, 'freddy', 9),
('TABLE REFRIGEREE GAUCHE', 'LABO', 0, 2, 4, 'freddy', 10);

-- 4. RLS (optionnel)
-- ============================================================
-- ALTER TABLE temp_frigos ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all for anon" ON temp_frigos FOR ALL USING (true);
-- ALTER TABLE temp_releves ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow all for anon" ON temp_releves FOR ALL USING (true);

-- 5. Verification
-- ============================================================
-- SELECT * FROM temp_frigos WHERE etablissement = 'freddy' ORDER BY ordre;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'temp_releves' ORDER BY ordinal_position;
