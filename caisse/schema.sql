-- ============================================
-- PlanB Tools - Module Contrôle de Caisse
-- Tables Supabase
-- ============================================

-- Table principale : saisie quotidienne du contrôle de caisse
CREATE TABLE IF NOT EXISTS caisse_controle (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),

    -- Chiffre d'affaires
    ca NUMERIC(10,2) DEFAULT 0,
    vae NUMERIC(10,2) DEFAULT 0,
    plus_cash NUMERIC(10,2) DEFAULT 0,

    -- Moyens de paiement CB
    cb_sans_contact NUMERIC(10,2) DEFAULT 0,
    cb_emv NUMERIC(10,2) DEFAULT 0,
    cb_sans_contact_sg NUMERIC(10,2) DEFAULT 0,
    cb_emv_sg NUMERIC(10,2) DEFAULT 0,
    cm_cic NUMERIC(10,2) DEFAULT 0,
    credit NUMERIC(10,2) DEFAULT 0,
    titres_restaurant NUMERIC(10,2) DEFAULT 0,
    amex NUMERIC(10,2) DEFAULT 0,

    -- Autres encaissements
    plus_tr NUMERIC(10,2) DEFAULT 0,
    plus_chq_virement NUMERIC(10,2) DEFAULT 0,
    pourboire_cb NUMERIC(10,2) DEFAULT 0,
    click_collect NUMERIC(10,2) DEFAULT 0,
    compte_client NUMERIC(10,2) DEFAULT 0,

    -- Mouvements de caisse
    acomptes_verse NUMERIC(10,2) DEFAULT 0,
    achats_divers NUMERIC(10,2) DEFAULT 0,
    prelevement NUMERIC(10,2) DEFAULT 0,
    depense_caisse NUMERIC(10,2) DEFAULT 0,
    ajout NUMERIC(10,2) DEFAULT 0,
    pourboires NUMERIC(10,2) DEFAULT 0,
    comptage_caisse NUMERIC(10,2) DEFAULT 0,

    -- Métadonnées
    saisi_par_id UUID,
    saisi_par_nom TEXT,
    valide BOOLEAN DEFAULT FALSE,
    valide_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(date, etablissement)
);

-- Table comptage : détail par coupure
CREATE TABLE IF NOT EXISTS caisse_comptage (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    date DATE NOT NULL,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),

    -- Stockage des quantités par coupure en JSON
    -- Ex: {"500":0,"200":1,"100":2,"50":5,"20":10,"10":3,"5":2,"2":5,"1":3,"0.5":2,"0.2":5,"0.1":3,"0.05":2,"0.02":1,"0.01":0}
    denominations JSONB DEFAULT '{}',
    total NUMERIC(10,2) DEFAULT 0,

    saisi_par_id UUID,
    saisi_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(date, etablissement)
);

-- Index pour recherches fréquentes
CREATE INDEX IF NOT EXISTS idx_caisse_controle_date_etab ON caisse_controle(date, etablissement);
CREATE INDEX IF NOT EXISTS idx_caisse_comptage_date_etab ON caisse_comptage(date, etablissement);

-- RLS (Row Level Security) - optionnel, à activer si nécessaire
-- ALTER TABLE caisse_controle ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE caisse_comptage ENABLE ROW LEVEL SECURITY;
