-- ============================================================
-- PRODUCTION MODULE - PHASE 2 : Productions & Lots
-- À exécuter dans Supabase SQL Editor
-- ============================================================

-- 1. Table lots_production
CREATE TABLE IF NOT EXISTS lots_production (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_lot TEXT NOT NULL UNIQUE,
  date_production DATE NOT NULL DEFAULT CURRENT_DATE,
  heure_debut TIME,
  heure_fin TIME,
  responsable_id UUID NOT NULL,
  responsable_nom TEXT NOT NULL,
  responsable_initiales TEXT,
  nb_productions INTEGER DEFAULT 0,
  statut TEXT NOT NULL DEFAULT 'ouvert' CHECK (statut IN ('ouvert', 'clos', 'archive')),
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index lots
CREATE INDEX IF NOT EXISTS idx_lots_date ON lots_production(date_production);
CREATE INDEX IF NOT EXISTS idx_lots_etablissement ON lots_production(etablissement);
CREATE INDEX IF NOT EXISTS idx_lots_statut ON lots_production(statut);

-- RLS lots
ALTER TABLE lots_production ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "lots_anon_all" ON lots_production;
CREATE POLICY "lots_anon_all" ON lots_production FOR ALL TO anon USING (true) WITH CHECK (true);

-- 2. Table productions
CREATE TABLE IF NOT EXISTS productions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiche_id UUID REFERENCES fiches_techniques(id) ON DELETE SET NULL,
  lot_id UUID NOT NULL REFERENCES lots_production(id) ON DELETE CASCADE,
  nom_produit TEXT NOT NULL,
  categorie TEXT NOT NULL CHECK (categorie IN ('mise_en_place', 'produit_intermediaire', 'produit_fini')),
  quantite_produite NUMERIC NOT NULL,
  unite TEXT NOT NULL DEFAULT 'pièces',
  date_production TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  dlc TIMESTAMPTZ,
  temperature_stockage TEXT,
  producteur_id UUID NOT NULL,
  producteur_nom TEXT NOT NULL,
  producteur_initiales TEXT,
  tache_id UUID,
  statut TEXT NOT NULL DEFAULT 'termine' CHECK (statut IN ('en_cours', 'termine', 'etiquete', 'stocke', 'consomme', 'jete')),
  observation TEXT,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index productions
CREATE INDEX IF NOT EXISTS idx_prod_date ON productions(date_production);
CREATE INDEX IF NOT EXISTS idx_prod_etablissement ON productions(etablissement);
CREATE INDEX IF NOT EXISTS idx_prod_lot ON productions(lot_id);
CREATE INDEX IF NOT EXISTS idx_prod_fiche ON productions(fiche_id);
CREATE INDEX IF NOT EXISTS idx_prod_statut ON productions(statut);

-- RLS productions
ALTER TABLE productions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "productions_anon_all" ON productions;
CREATE POLICY "productions_anon_all" ON productions FOR ALL TO anon USING (true) WITH CHECK (true);

-- 3. Colonnes supplémentaires sur predefined_tasks
ALTER TABLE predefined_tasks ADD COLUMN IF NOT EXISTS is_production BOOLEAN DEFAULT false;
ALTER TABLE predefined_tasks ADD COLUMN IF NOT EXISTS fiche_id UUID REFERENCES fiches_techniques(id) ON DELETE SET NULL;
ALTER TABLE predefined_tasks ADD COLUMN IF NOT EXISTS categorie_production TEXT CHECK (categorie_production IS NULL OR categorie_production IN ('mise_en_place', 'produit_intermediaire', 'produit_fini'));

-- 4. Fonction pour générer le prochain numéro de lot du jour
CREATE OR REPLACE FUNCTION next_lot_number(p_date DATE, p_etablissement TEXT)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_count INTEGER;
  v_number TEXT;
BEGIN
  v_prefix := TO_CHAR(p_date, 'YYYY-MM-DD');

  SELECT COUNT(*) + 1 INTO v_count
  FROM lots_production
  WHERE date_production = p_date
    AND etablissement = p_etablissement;

  v_number := v_prefix || '-' || LPAD(v_count::TEXT, 3, '0');
  RETURN v_number;
END;
$$ LANGUAGE plpgsql;

-- 5. Marquer les predefined_tasks existantes comme production
-- Catégories production : Cuissons, Découpes, Garnitures, Pâtisserie, Préparations
-- Catégories NON production : Nettoyage, Mise en place & Contrôle (mixte)
UPDATE predefined_tasks SET is_production = true
WHERE categorie IN ('Cuissons', 'Découpes & Épluchage', 'Garnitures & Accompagnements', 'Pâtisserie', 'Préparations');

-- Mapper les catégories production
UPDATE predefined_tasks SET categorie_production = 'mise_en_place'
WHERE categorie IN ('Découpes & Épluchage', 'Préparations') AND is_production = true;

UPDATE predefined_tasks SET categorie_production = 'produit_intermediaire'
WHERE categorie IN ('Cuissons') AND is_production = true;

UPDATE predefined_tasks SET categorie_production = 'produit_fini'
WHERE categorie IN ('Garnitures & Accompagnements', 'Pâtisserie') AND is_production = true;

-- 6. Lier les predefined_tasks aux fiches_techniques existantes (par nom)
UPDATE predefined_tasks pt
SET fiche_id = ft.id
FROM fiches_techniques ft
WHERE LOWER(TRIM(pt.nom)) = LOWER(TRIM(ft.nom))
  AND (pt.etablissement = ft.etablissement OR pt.etablissement IS NULL)
  AND pt.is_production = true;

-- 7. Colonnes production sur la table tasks (propagation depuis predefined_tasks)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_production BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS fiche_id UUID REFERENCES fiches_techniques(id) ON DELETE SET NULL;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS categorie_production TEXT CHECK (categorie_production IS NULL OR categorie_production IN ('mise_en_place', 'produit_intermediaire', 'produit_fini'));
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS production_id UUID REFERENCES productions(id) ON DELETE SET NULL;

-- 8. Vérification
SELECT
  'predefined_tasks marquées production' AS info,
  COUNT(*) FILTER (WHERE is_production = true) AS production,
  COUNT(*) FILTER (WHERE is_production = false OR is_production IS NULL) AS non_production,
  COUNT(*) FILTER (WHERE fiche_id IS NOT NULL) AS liees_fiche
FROM predefined_tasks;
