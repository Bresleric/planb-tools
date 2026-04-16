-- ============================================================
-- Module Numérisations - Schéma SQL
-- Hub central de numérisation via Scanner Pro
-- 4 types : facture, bl, etiquette_mp, etiquette_prod
-- A exécuter dans Supabase SQL Editor AVANT le déploiement
-- ============================================================

-- 1. Table principale : documents numérisés
-- ============================================================
CREATE TABLE IF NOT EXISTS numerisations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Type de document
    type TEXT NOT NULL CHECK (type IN ('facture', 'bl', 'etiquette_mp', 'etiquette_prod')),

    -- Fournisseur (pour factures, BL, étiquettes MP)
    fournisseur_id UUID REFERENCES appro_fournisseurs(id),
    fournisseur_nom TEXT,

    -- Infos document
    date_document DATE NOT NULL DEFAULT CURRENT_DATE,
    reference TEXT,                    -- n° facture/BL
    designation TEXT,                  -- nom du produit (étiquettes)

    -- Traçabilité / DLC (étiquettes)
    lot TEXT,                          -- numéro de lot
    dlc DATE,                          -- date limite de consommation
    date_fabrication DATE,             -- date de fabrication (prod maison)

    -- Lien avec d'autres modules
    commande_id UUID,                  -- lien vers appro_commandes
    fiche_technique_id UUID,           -- lien vers fiches_techniques (prod)
    reception_id UUID,                 -- lien vers receptions_documents

    -- Statut et validation
    statut TEXT DEFAULT 'a_traiter' CHECK (statut IN ('a_traiter', 'traite', 'archive', 'probleme')),
    observation TEXT,

    -- Fichier numérisé
    nb_pages INTEGER DEFAULT 0,
    pdf_data TEXT,                     -- PDF en base64 (data URI)
    texte_ocr TEXT,                    -- texte OCR combiné

    -- Utilisateur
    user_id UUID NOT NULL,
    user_nom TEXT NOT NULL,
    user_initiales TEXT,

    -- Traitement
    traite_par_id UUID,
    traite_par_nom TEXT,
    date_traitement TIMESTAMPTZ,

    -- Contexte
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_num_date ON numerisations(date_document, etablissement);
CREATE INDEX IF NOT EXISTS idx_num_type ON numerisations(type, etablissement);
CREATE INDEX IF NOT EXISTS idx_num_statut ON numerisations(statut, etablissement);
CREATE INDEX IF NOT EXISTS idx_num_fournisseur ON numerisations(fournisseur_id) WHERE fournisseur_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_num_dlc ON numerisations(dlc) WHERE dlc IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_num_fiche ON numerisations(fiche_technique_id) WHERE fiche_technique_id IS NOT NULL;

-- 2. Table des pages/photos (multi-pages par document)
-- ============================================================
CREATE TABLE IF NOT EXISTS numerisations_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES numerisations(id) ON DELETE CASCADE,
    page_num INTEGER NOT NULL DEFAULT 1,
    photo_data TEXT NOT NULL,           -- base64 du scan (compressé)
    texte_ocr TEXT,                     -- texte extrait par page
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(document_id, page_num)
);

CREATE INDEX IF NOT EXISTS idx_num_pages_doc ON numerisations_pages(document_id);

-- ============================================================
-- RLS Policies (public access via anon key - même pattern que les autres modules)
-- ============================================================
ALTER TABLE numerisations ENABLE ROW LEVEL SECURITY;
ALTER TABLE numerisations_pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_all" ON numerisations FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON numerisations_pages FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- Vérification
-- ============================================================
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'numerisations' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'numerisations_pages' ORDER BY ordinal_position;
