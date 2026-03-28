-- ============================================
-- Module Approvisionnement — Schéma Supabase
-- PlanB Tools — Mars 2026
-- ============================================

-- 1. FOURNISSEURS
CREATE TABLE IF NOT EXISTS appro_fournisseurs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nom text NOT NULL,
    contact text,
    email text,
    tel text,
    site_web text,
    mode_commande text DEFAULT 'manuel', -- manuel, email, choco, site_web
    notes text,
    etablissement text, -- null = partagé entre établissements
    actif boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

-- 2. CATALOGUE ARTICLES (noms génériques normalisés)
CREATE TABLE IF NOT EXISTS appro_catalogue (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    nom text NOT NULL,
    nom_recherche text NOT NULL, -- lowercase sans accents pour recherche rapide
    categorie text,
    unite text NOT NULL DEFAULT 'kg',
    etablissement text, -- null = partagé entre établissements
    actif boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_appro_catalogue_recherche ON appro_catalogue(nom_recherche);
CREATE INDEX IF NOT EXISTS idx_appro_catalogue_categorie ON appro_catalogue(categorie);

-- 3. PRIX PAR ARTICLE × FOURNISSEUR (avec historique)
CREATE TABLE IF NOT EXISTS appro_prix (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    article_id uuid NOT NULL REFERENCES appro_catalogue(id) ON DELETE CASCADE,
    fournisseur_id uuid NOT NULL REFERENCES appro_fournisseurs(id) ON DELETE CASCADE,
    designation text, -- désignation chez le fournisseur
    reference_fournisseur text,
    conditionnement text,
    pu_ht numeric(10,4) NOT NULL,
    unite text,
    taux_tva numeric(5,4) DEFAULT 0.055,
    date_prix date DEFAULT CURRENT_DATE,
    source text, -- 'import_2025', 'import_2026', 'facture', 'manuel'
    etablissement text,
    actif boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_appro_prix_article ON appro_prix(article_id);
CREATE INDEX IF NOT EXISTS idx_appro_prix_fournisseur ON appro_prix(fournisseur_id);

-- 4. BESOINS (liste des courses)
CREATE TABLE IF NOT EXISTS appro_besoins (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    article_id uuid REFERENCES appro_catalogue(id),
    article_nom text NOT NULL,
    etablissement text NOT NULL,
    demandeur_id uuid,
    demandeur_nom text,
    demandeur_initiales text,
    quantite numeric(10,2),
    unite text,
    urgence boolean DEFAULT false,
    observation text,
    statut text DEFAULT 'demande', -- demande, valide, commande, annule
    date_demande timestamptz DEFAULT now(),
    valide_par_id uuid,
    valide_par_nom text,
    date_validation timestamptz,
    commande_id uuid
);
CREATE INDEX IF NOT EXISTS idx_appro_besoins_etab_statut ON appro_besoins(etablissement, statut);

-- 5. COMMANDES (regroupées par fournisseur)
CREATE TABLE IF NOT EXISTS appro_commandes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    fournisseur_id uuid REFERENCES appro_fournisseurs(id),
    fournisseur_nom text NOT NULL,
    etablissement text NOT NULL,
    statut text DEFAULT 'brouillon', -- brouillon, validee, envoyee, recue, annulee
    total_ht numeric(12,2),
    total_ttc numeric(12,2),
    creee_par_id uuid,
    creee_par_nom text,
    validee_par_id uuid,
    validee_par_nom text,
    date_creation timestamptz DEFAULT now(),
    date_validation timestamptz,
    date_envoi timestamptz,
    notes text
);
CREATE INDEX IF NOT EXISTS idx_appro_commandes_etab ON appro_commandes(etablissement, statut);

-- 6. LIGNES DE COMMANDE
CREATE TABLE IF NOT EXISTS appro_commande_lignes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    commande_id uuid NOT NULL REFERENCES appro_commandes(id) ON DELETE CASCADE,
    article_id uuid REFERENCES appro_catalogue(id),
    prix_id uuid REFERENCES appro_prix(id),
    designation text NOT NULL,
    quantite numeric(10,2) NOT NULL,
    unite text,
    pu_ht numeric(10,4),
    montant_ht numeric(12,2),
    taux_tva numeric(5,4),
    montant_ttc numeric(12,2)
);
CREATE INDEX IF NOT EXISTS idx_appro_lignes_commande ON appro_commande_lignes(commande_id);

-- ============================================
-- RLS Policies (public access via anon key)
-- ============================================
ALTER TABLE appro_fournisseurs ENABLE ROW LEVEL SECURITY;
ALTER TABLE appro_catalogue ENABLE ROW LEVEL SECURITY;
ALTER TABLE appro_prix ENABLE ROW LEVEL SECURITY;
ALTER TABLE appro_besoins ENABLE ROW LEVEL SECURITY;
ALTER TABLE appro_commandes ENABLE ROW LEVEL SECURITY;
ALTER TABLE appro_commande_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_all" ON appro_fournisseurs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON appro_catalogue FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON appro_prix FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON appro_besoins FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON appro_commandes FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON appro_commande_lignes FOR ALL USING (true) WITH CHECK (true);
