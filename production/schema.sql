-- ============================================
-- MODULE PRODUCTION - Phase 1 : Fiches Techniques
-- PlanB Tools - Supabase Migration
-- 30 mars 2026
-- ============================================

-- Table principale : fiches techniques (recettes)
CREATE TABLE IF NOT EXISTS fiches_techniques (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nom TEXT NOT NULL,
  categorie TEXT NOT NULL DEFAULT 'produit_fini',  -- mise_en_place, produit_intermediaire, produit_fini
  sous_categorie TEXT,                              -- ex: sauces, garnitures, desserts, entrées...

  -- Rendement
  rendement_quantite NUMERIC,
  rendement_unite TEXT DEFAULT 'portions',           -- portions, kg, litres, pièces

  -- Temps
  temps_preparation INTEGER,                         -- en minutes
  temps_cuisson INTEGER,                             -- en minutes
  temps_repos INTEGER,                               -- en minutes

  -- Conservation
  dlc_jours INTEGER,                                 -- durée de conservation en jours
  dlc_heures INTEGER,                                -- ou en heures (pour produits très frais)
  temperature_stockage TEXT,                          -- ex: "0-4°C", "ambiant", "-18°C"
  conditionnement TEXT,                               -- ex: "bac GN 1/1", "sous-vide", "barquette"

  -- Allergènes (tableau JSON)
  allergenes JSONB DEFAULT '[]'::jsonb,              -- ["gluten","lait","oeufs","fruits_a_coque",...]

  -- Instructions
  instructions TEXT,                                  -- étapes de préparation (texte libre)
  notes TEXT,                                         -- notes complémentaires

  -- Photo (URL ou base64)
  photo_url TEXT,

  -- Coût
  cout_total NUMERIC DEFAULT 0,                      -- calculé depuis ingrédients
  cout_portion NUMERIC DEFAULT 0,                     -- cout_total / rendement_quantite

  -- Métadonnées
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  actif BOOLEAN DEFAULT true,
  cree_par_id UUID,
  cree_par_nom TEXT,
  modifie_par_id UUID,
  modifie_par_nom TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table ingrédients par fiche
CREATE TABLE IF NOT EXISTS fiche_ingredients (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  fiche_id UUID NOT NULL REFERENCES fiches_techniques(id) ON DELETE CASCADE,

  -- Ingrédient
  nom TEXT NOT NULL,                                  -- nom de l'ingrédient
  article_id UUID,                                    -- lien optionnel vers appro_catalogue

  -- Quantité
  quantite NUMERIC NOT NULL,
  unite TEXT NOT NULL DEFAULT 'kg',                   -- kg, g, l, cl, ml, pièce, botte...

  -- Coût
  prix_unitaire NUMERIC DEFAULT 0,                    -- prix par unité
  cout_ligne NUMERIC DEFAULT 0,                       -- quantite × prix_unitaire

  -- Ordre d'affichage
  ordre INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index pour performance
CREATE INDEX IF NOT EXISTS idx_fiches_techniques_etablissement ON fiches_techniques(etablissement);
CREATE INDEX IF NOT EXISTS idx_fiches_techniques_categorie ON fiches_techniques(categorie, etablissement);
CREATE INDEX IF NOT EXISTS idx_fiches_techniques_actif ON fiches_techniques(actif, etablissement);
CREATE INDEX IF NOT EXISTS idx_fiche_ingredients_fiche ON fiche_ingredients(fiche_id);

-- RLS (Row Level Security) - désactivé pour simplifier (accès via anon key)
ALTER TABLE fiches_techniques ENABLE ROW LEVEL SECURITY;
ALTER TABLE fiche_ingredients ENABLE ROW LEVEL SECURITY;

-- Politique permissive pour anon (comme les autres tables)
CREATE POLICY "Allow all for anon" ON fiches_techniques FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for anon" ON fiche_ingredients FOR ALL USING (true) WITH CHECK (true);
