-- ============================================
-- PlanB Tools - Module Briefings
-- Tables Supabase
-- ============================================

-- Table de prévisions : données chiffrées N-1 et prévisions
-- Permet de stocker les chiffres historiques et attendus par date/service
CREATE TABLE IF NOT EXISTS briefing_previsions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "date" DATE NOT NULL,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
    service TEXT CHECK (service IN ('midi', 'soir')),

    -- Chiffres N-1 (même jour l'année précédente)
    ca_n1 NUMERIC(10,2) DEFAULT 0,
    couverts_n1 INTEGER DEFAULT 0,
    ticket_moyen_n1 NUMERIC(10,2) DEFAULT 0,

    -- Chiffres de la veille
    ca_veille NUMERIC(10,2) DEFAULT 0,
    couverts_veille INTEGER DEFAULT 0,
    ticket_moyen_veille NUMERIC(10,2) DEFAULT 0,

    -- Prévisions du jour
    reservations INTEGER DEFAULT 0,
    couverts_attendus INTEGER DEFAULT 0,
    ca_prevu NUMERIC(10,2) DEFAULT 0,

    -- Métadonnées
    notes TEXT,
    saisi_par_id UUID,
    saisi_par_nom TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE("date", etablissement, service)
);

-- Table principale : le briefing
CREATE TABLE IF NOT EXISTS briefings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    "date" DATE NOT NULL,
    etablissement TEXT NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
    type TEXT NOT NULL CHECK (type IN ('jour', 'service')),
    service TEXT CHECK (service IN ('midi', 'soir')),
    -- service est NULL si type='jour', obligatoire si type='service'

    statut TEXT NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon', 'publie')),

    -- Section 1 : Répartition des équipes (JSONB)
    -- Format: [{ "user_id": "...", "nom": "...", "initiales": "...", "equipe": "salle", "poste": "rang 1", "horaire": "10h-15h" }]
    equipes JSONB DEFAULT '[]',

    -- Section 2 : Chiffres clés (JSONB)
    -- Format: { "ca_veille": 0, "couverts_veille": 0, "ticket_moyen_veille": 0, "ca_n1": 0, "couverts_n1": 0, "reservations": 0, "couverts_attendus": 0, "ca_prevu": 0 }
    chiffres JSONB DEFAULT '{}',

    -- Section 3 : Produits en quantité limitée (JSONB)
    -- Format: [{ "produit": "...", "quantite": 0, "unite": "portions", "observation": "" }]
    produits_limites JSONB DEFAULT '[]',

    -- Section 4 : Produits à dates courtes (JSONB)
    -- Format: [{ "produit": "...", "date_limite": "2026-03-30", "action": "mettre en avant", "observation": "" }]
    produits_dates_courtes JSONB DEFAULT '[]',

    -- Section 5 : Incidents veille + mesures correctives (JSONB)
    -- Format: [{ "description": "...", "mesure_corrective": "...", "priorite": "haute" }]
    incidents JSONB DEFAULT '[]',

    -- Section 6 : Rappels du jour (JSONB)
    -- Format: [{ "message": "...", "categorie": "service" }]
    rappels JSONB DEFAULT '[]',

    -- Section 7 : VIP / Événements spéciaux (JSONB)
    -- Format: [{ "type": "vip", "description": "Table 12 - anniversaire M. Dupont", "heure": "20h", "couverts": 8, "allergies": "gluten" }]
    evenements JSONB DEFAULT '[]',

    -- Section 8 : Plats du jour / Suggestions à pousser (JSONB)
    -- Format: [{ "plat": "...", "prix": 0, "commentaire": "Nouvelle recette, insister dessus" }]
    plats_suggestions JSONB DEFAULT '[]',

    -- Section 9 : Objectifs du service
    -- Format: [{ "objectif": "Temps d'attente < 15min", "priorite": "haute" }]
    objectifs JSONB DEFAULT '[]',

    -- Notes libres
    notes_libres TEXT,

    -- Métadonnées
    cree_par_id UUID,
    cree_par_nom TEXT,
    publie_par_id UUID,
    publie_par_nom TEXT,
    publie_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE("date", etablissement, type, service)
);

-- Table des accusés de lecture
CREATE TABLE IF NOT EXISTS briefing_lectures (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    briefing_id UUID NOT NULL REFERENCES briefings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_nom TEXT NOT NULL,
    user_initiales TEXT NOT NULL,
    lu_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(briefing_id, user_id)
);

-- Index pour recherches fréquentes
CREATE INDEX IF NOT EXISTS idx_briefings_date_etab ON briefings("date", etablissement);
CREATE INDEX IF NOT EXISTS idx_briefing_previsions_date_etab ON briefing_previsions("date", etablissement);
CREATE INDEX IF NOT EXISTS idx_briefing_lectures_briefing ON briefing_lectures(briefing_id);

-- RLS (Row Level Security) - à activer si nécessaire
-- ALTER TABLE briefings ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE briefing_previsions ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE briefing_lectures ENABLE ROW LEVEL SECURITY;
