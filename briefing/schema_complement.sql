-- ============================================
-- PlanB Tools - Module Briefings
-- Tables complémentaires
-- ============================================

-- Table historique des incidents (persistant)
-- Permet de garder un historique de tous les incidents
-- et de suivre les mesures correctives dans le temps
CREATE TABLE IF NOT EXISTS briefing_incidents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "date" DATE NOT NULL,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
    service TEXT CHECK (service IN ('midi', 'soir')),
    description TEXT NOT NULL,
    mesure_corrective TEXT,
    categorie TEXT CHECK (categorie IN ('service', 'cuisine', 'hygiene', 'securite', 'equipement', 'client', 'autre')),
    priorite TEXT DEFAULT 'moyenne' CHECK (priorite IN ('haute', 'moyenne', 'basse')),
    statut TEXT DEFAULT 'ouvert' CHECK (statut IN ('ouvert', 'en_cours', 'resolu')),
    resolu_at TIMESTAMPTZ,
    resolu_par_nom TEXT,
    cree_par_id UUID,
    cree_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incidents_date_etab ON briefing_incidents("date", etablissement);
CREATE INDEX IF NOT EXISTS idx_incidents_statut ON briefing_incidents(statut);

-- Table des rappels (base persistante, affichage aléatoire)
-- Les managers/admins ajoutent des rappels qui apparaissent aléatoirement dans les briefings
CREATE TABLE IF NOT EXISTS briefing_rappels (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
    message TEXT NOT NULL,
    categorie TEXT DEFAULT 'service' CHECK (categorie IN ('service', 'hygiene', 'securite', 'pratique', 'autre')),
    equipe TEXT CHECK (equipe IN ('salle', 'cuisine', 'plonge', 'autre', 'tous')),
    priorite TEXT DEFAULT 'normale' CHECK (priorite IN ('haute', 'normale')),
    actif BOOLEAN DEFAULT TRUE,
    -- Fréquence d'affichage : combien de fois par semaine max
    frequence_max INTEGER DEFAULT 3,
    dernier_affichage DATE,
    nb_affichages INTEGER DEFAULT 0,
    cree_par_id UUID,
    cree_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rappels_etab_actif ON briefing_rappels(etablissement, actif);

-- Table catalogue produits (pour lier aux produits limités et dates courtes)
-- Référentiel partagé entre briefings et approvisionnement
CREATE TABLE IF NOT EXISTS briefing_produits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nom TEXT NOT NULL,
    nom_recherche TEXT,
    categorie TEXT CHECK (categorie IN ('entree', 'plat', 'dessert', 'boisson', 'ingredient', 'autre')),
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
    actif BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(nom, etablissement)
);

CREATE INDEX IF NOT EXISTS idx_produits_etab ON briefing_produits(etablissement, actif);

-- Table résumés hebdomadaires des notes libres
-- Générée automatiquement ou manuellement pour suivi
CREATE TABLE IF NOT EXISTS briefing_resume_hebdo (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    semaine_debut DATE NOT NULL,
    semaine_fin DATE NOT NULL,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
    resume TEXT,
    actions_proposees JSONB DEFAULT '[]',
    -- Format: [{ "action": "...", "responsable": "...", "echeance": "2026-04-05", "statut": "a_faire" }]
    cree_par TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(semaine_debut, etablissement)
);
