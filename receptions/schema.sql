-- ============================================================
-- Module Réceptions - Schéma SQL
-- Numérisation Factures/BL et Étiquettes produits
-- A exécuter dans Supabase SQL Editor AVANT le déploiement
-- ============================================================

-- 1. Table principale : documents de réception
-- ============================================================
CREATE TABLE IF NOT EXISTS receptions_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('facture', 'etiquette')),
    fournisseur_id UUID REFERENCES appro_fournisseurs(id),
    fournisseur_nom TEXT NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    reference TEXT,  -- numéro facture/BL (pour factures)
    commande_id UUID REFERENCES appro_commandes(id),  -- lien commande appro (optionnel)
    statut TEXT DEFAULT 'en_attente' CHECK (statut IN ('en_attente', 'valide', 'rejete')),
    observation TEXT,
    nb_pages INTEGER DEFAULT 0,
    user_id UUID NOT NULL,
    user_nom TEXT NOT NULL,
    user_initiales TEXT,
    valide_par_id UUID,
    valide_par_nom TEXT,
    date_validation TIMESTAMPTZ,
    pdf_data TEXT,             -- PDF searchable en base64 (data URI)
    texte_ocr TEXT,            -- texte OCR combine de toutes les pages
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index pour requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_receptions_docs_date ON receptions_documents(date, etablissement);
CREATE INDEX IF NOT EXISTS idx_receptions_docs_type ON receptions_documents(type, etablissement);
CREATE INDEX IF NOT EXISTS idx_receptions_docs_statut ON receptions_documents(statut, etablissement);
CREATE INDEX IF NOT EXISTS idx_receptions_docs_fournisseur ON receptions_documents(fournisseur_id);
CREATE INDEX IF NOT EXISTS idx_receptions_docs_commande ON receptions_documents(commande_id) WHERE commande_id IS NOT NULL;

-- 2. Table des pages/photos (multi-pages par document)
-- ============================================================
CREATE TABLE IF NOT EXISTS receptions_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES receptions_documents(id) ON DELETE CASCADE,
    page_num INTEGER NOT NULL DEFAULT 1,
    photo_data TEXT NOT NULL,  -- base64 du scan (traite: contraste + binarisation)
    texte_ocr TEXT,            -- texte extrait par OCR (Tesseract.js, langue: fra)
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(document_id, page_num)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_receptions_pages_doc ON receptions_pages(document_id);

-- ============================================================
-- RLS Policies (public access via anon key)
-- ============================================================
ALTER TABLE receptions_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE receptions_pages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_all" ON receptions_documents FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON receptions_pages FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- Vérification
-- ============================================================
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'receptions_documents' ORDER BY ordinal_position;
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'receptions_pages' ORDER BY ordinal_position;
