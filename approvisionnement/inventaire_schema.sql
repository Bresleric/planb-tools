-- ============================================================
-- Module Inventaire Journalier - Schéma SQL
-- Sous-module de Approvisionnement
-- A exécuter dans Supabase SQL Editor AVANT le déploiement
-- ============================================================

-- 1. Table entête : inventaire du jour par établissement
-- ============================================================
CREATE TABLE IF NOT EXISTS appro_inventaire_journalier (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    statut TEXT DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'valide')),
    cree_par_id UUID,
    cree_par_nom TEXT,
    valide_par_id UUID,
    valide_par_nom TEXT,
    date_validation TIMESTAMPTZ,
    observation TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(date, etablissement)
);

CREATE INDEX IF NOT EXISTS idx_inventaire_jour_date ON appro_inventaire_journalier(date, etablissement);
CREATE INDEX IF NOT EXISTS idx_inventaire_jour_statut ON appro_inventaire_journalier(statut, etablissement);

-- 2. Table lignes : articles inventoriés du jour
-- ============================================================
CREATE TABLE IF NOT EXISTS appro_inventaire_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventaire_id UUID NOT NULL REFERENCES appro_inventaire_journalier(id) ON DELETE CASCADE,
    article_id UUID REFERENCES appro_catalogue(id),
    article_nom TEXT NOT NULL,
    categorie TEXT,
    unite TEXT,
    type_tirage TEXT DEFAULT 'auto' CHECK (type_tirage IN ('auto', 'manuel')),
    quantite NUMERIC(10,3),
    observation TEXT,
    saisi_par_id UUID,
    saisi_par_nom TEXT,
    saisi_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventaire_lignes_inv ON appro_inventaire_lignes(inventaire_id);
CREATE INDEX IF NOT EXISTS idx_inventaire_lignes_article ON appro_inventaire_lignes(article_id);

-- ============================================================
-- RLS Policies
-- ============================================================
ALTER TABLE appro_inventaire_journalier ENABLE ROW LEVEL SECURITY;
ALTER TABLE appro_inventaire_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_all" ON appro_inventaire_journalier FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON appro_inventaire_lignes FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- Vérification
-- ============================================================
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'appro_inventaire_journalier' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'appro_inventaire_lignes' ORDER BY ordinal_position;
