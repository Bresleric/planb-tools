-- ============================================
-- Migration : flux de reception appro_ingredients
-- Module Approvisionnement — PlanB Tools — 06/06/2026
-- ============================================
-- Ajoute categorie_flux : 'scan' (viande/charcuterie/cremerie/poisson, tracabilite lot+DLC)
-- vs 'validation' (F&L, epicerie, oeufs, autres : saisie manuelle quantite + visuel).
-- Idempotente. Deja appliquee en base le 06/06/2026 (migration appro_ingredients_categorie_flux).
-- ============================================

-- Tache 1 : flux de reception (scan vs validation manuelle)
ALTER TABLE appro_ingredients
  ADD COLUMN IF NOT EXISTS categorie_flux TEXT DEFAULT 'validation';

CREATE INDEX IF NOT EXISTS idx_appro_ingredients_flux
  ON appro_ingredients(categorie_flux);

-- Toute la categorie viande et charcuterie -> scan
UPDATE appro_ingredients
SET categorie_flux = 'scan'
WHERE categorie = 'Viande & charcuterie';

-- Articles cremerie / viande / poisson ranges sous 'Frais' -> scan (curation manuelle)
-- NB : la categorie 'Frais' est un melange (cremerie, viande, poisson, mais aussi F&L et
-- desserts), d ou la liste explicite ci-dessous plutot qu un filtre par categorie.
UPDATE appro_ingredients
SET categorie_flux = 'scan'
WHERE categorie = 'Frais'
  AND nom IN (
    'Beurre Campagne',
    'Bûchette de chèvre',
    'Crème liquide 5L',
    'DEBIC R&F HL',
    'Emmental Rape Std Valmartin Mm',
    'Fromage blanc',
    'Munster Blanc',
    'Yaourt vanille',
    'Boeuf Bourguignon Genisse Charolaise Cb',
    'Choucroute Crue Nouvelle',
    'Gendarmes',
    'Onglet',
    'Onglet De Veau',
    'Paleron',
    'Porc pour Baekeoffe',
    'Poulet Ath',
    'Poulet Extra',
    'Tourte Marinee',
    'Saumon fumé'
  );

-- Verification post-migration :
--   SELECT categorie_flux, count(*) FROM appro_ingredients GROUP BY categorie_flux;
--   Attendu : scan = 48, validation = 397.
