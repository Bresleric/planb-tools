-- ============================================================
-- MODULE VENTES - Import L'Addition & Suivi des ventes
-- PlanB Tools - Supabase Migration
-- 31 mars 2026
-- ============================================================

-- 1. Table ventes journalières (CA, couverts, ticket moyen par service)
CREATE TABLE IF NOT EXISTS ventes_journalieres (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Date et service
  date DATE NOT NULL,
  service TEXT NOT NULL CHECK (service IN ('midi', 'soir', 'journee')),

  -- Indicateurs clés
  ca_ttc NUMERIC NOT NULL DEFAULT 0,              -- Chiffre d'affaires TTC
  ca_ht NUMERIC DEFAULT 0,                         -- Chiffre d'affaires HT
  couverts INTEGER NOT NULL DEFAULT 0,             -- Nombre de couverts
  ticket_moyen NUMERIC GENERATED ALWAYS AS (
    CASE WHEN couverts > 0 THEN ROUND(ca_ttc / couverts, 2) ELSE 0 END
  ) STORED,                                        -- Ticket moyen auto-calculé

  -- Détails complémentaires
  nb_tables INTEGER,                               -- Nombre de tables servies
  nb_additions INTEGER,                            -- Nombre d'additions
  ca_emporter NUMERIC DEFAULT 0,                   -- CA vente à emporter
  ca_sur_place NUMERIC DEFAULT 0,                  -- CA sur place

  -- Moyens de paiement
  paiement_cb NUMERIC DEFAULT 0,
  paiement_especes NUMERIC DEFAULT 0,
  paiement_tickets NUMERIC DEFAULT 0,              -- Tickets restaurant
  paiement_autres NUMERIC DEFAULT 0,

  -- Source et métadonnées
  source TEXT NOT NULL DEFAULT 'manuel' CHECK (source IN ('csv', 'manuel', 'api')),
  import_id UUID,                                  -- Référence à l'import CSV
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  saisi_par_id UUID,
  saisi_par_nom TEXT,
  notes TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unicité : une seule entrée par date/service/établissement
  UNIQUE(date, service, etablissement)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_ventes_j_date ON ventes_journalieres(date);
CREATE INDEX IF NOT EXISTS idx_ventes_j_etab ON ventes_journalieres(etablissement);
CREATE INDEX IF NOT EXISTS idx_ventes_j_date_etab ON ventes_journalieres(date, etablissement);

-- RLS
ALTER TABLE ventes_journalieres ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ventes_j_anon_all" ON ventes_journalieres FOR ALL TO anon USING (true) WITH CHECK (true);


-- 2. Table ventes par produit (détail)
CREATE TABLE IF NOT EXISTS ventes_produits (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Date et service
  date DATE NOT NULL,
  service TEXT NOT NULL CHECK (service IN ('midi', 'soir', 'journee')),

  -- Produit
  nom_produit TEXT NOT NULL,
  categorie_produit TEXT,                          -- Entrée, Plat, Dessert, Boisson, etc.
  code_produit TEXT,                               -- Code L'Addition si disponible

  -- Quantités et CA
  quantite INTEGER NOT NULL DEFAULT 0,
  ca_ttc NUMERIC NOT NULL DEFAULT 0,
  prix_unitaire NUMERIC GENERATED ALWAYS AS (
    CASE WHEN quantite > 0 THEN ROUND(ca_ttc / quantite, 2) ELSE 0 END
  ) STORED,

  -- Lien fiche technique (pour calcul food cost)
  fiche_id UUID REFERENCES fiches_techniques(id) ON DELETE SET NULL,

  -- Source
  source TEXT NOT NULL DEFAULT 'csv' CHECK (source IN ('csv', 'manuel', 'api')),
  import_id UUID,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_ventes_p_date ON ventes_produits(date);
CREATE INDEX IF NOT EXISTS idx_ventes_p_etab ON ventes_produits(etablissement);
CREATE INDEX IF NOT EXISTS idx_ventes_p_nom ON ventes_produits(nom_produit, etablissement);
CREATE INDEX IF NOT EXISTS idx_ventes_p_fiche ON ventes_produits(fiche_id);

-- RLS
ALTER TABLE ventes_produits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ventes_p_anon_all" ON ventes_produits FOR ALL TO anon USING (true) WITH CHECK (true);


-- 3. Table historique des imports CSV
CREATE TABLE IF NOT EXISTS ventes_imports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nom_fichier TEXT NOT NULL,
  type_import TEXT NOT NULL CHECK (type_import IN ('journalier', 'produits', 'mixte')),
  nb_lignes INTEGER DEFAULT 0,
  periode_debut DATE,
  periode_fin DATE,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  importe_par_id UUID,
  importe_par_nom TEXT,
  statut TEXT NOT NULL DEFAULT 'ok' CHECK (statut IN ('ok', 'partiel', 'erreur')),
  erreurs JSONB DEFAULT '[]'::jsonb,               -- Liste des erreurs rencontrées
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE ventes_imports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ventes_i_anon_all" ON ventes_imports FOR ALL TO anon USING (true) WITH CHECK (true);


-- 4. Vérification
SELECT 'Tables ventes créées' AS info,
  (SELECT COUNT(*) FROM ventes_journalieres) AS nb_ventes_j,
  (SELECT COUNT(*) FROM ventes_produits) AS nb_ventes_p,
  (SELECT COUNT(*) FROM ventes_imports) AS nb_imports;
