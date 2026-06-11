-- ============================================================
-- Migration — Primitive "Prelevement de stock" (unifiee)
-- Module Production + Stock / PlanB-Tools
-- Projet Supabase : dzrherfavgiuygnimtux
-- Idempotente : re-executable sans erreur.
-- RLS obligatoire (regle CLAUDE.md sec.8) : policy permissive anon.
-- A executer dans Supabase > SQL Editor si le MCP est read-only.
-- ------------------------------------------------------------
-- Remplace l'ancien migration_rapprochement_lots.sql (non deploye).
-- Modele : un PRELEVEMENT = sortie d'un lot RECEPTIONNE du stock,
--   declenchee par un scan rapproche automatiquement. Reutilise par
--   la production ET la sortie manuelle (motif polymorphe). Une
--   etiquette ENFANT n'est creee QUE si on reconditionne une partie.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Table des prelevements (geste unique production + sortie manuelle)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prelevements (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  etablissement         text NOT NULL,
  article_id            uuid,                 -- article preleve (resolu)
  lot_recu_scan_id      uuid,                 -- scan_tracabilite RECEPTIONNE decremente (lot parent)
  scan_prod_id          uuid,                 -- etiquette scannee au prelevement (OCR du paquet)
  methode_match         text,                 -- empreinte_dlc_poids | lot_exact | lot_fuzzy | apprentissage | manuel
  score_match           integer,
  statut                text NOT NULL DEFAULT 'suggere',  -- suggere | valide | annule
  quantite              numeric,
  unite                 text DEFAULT 'kg',
  prend_tout            boolean DEFAULT true, -- true = paquet entier ; false = partiel (reconditionne)
  stock_mouvement_id    uuid,                 -- la SORTIE creee a la validation
  etiquette_prelevement_id uuid,             -- etiquette ENFANT si reconditionnement (nullable)
  -- Motif polymorphe : a quoi sert ce prelevement
  motif_type            text NOT NULL DEFAULT 'sortie_manuelle', -- production | sortie_manuelle | repas_personnel | mise_en_place | autre
  motif_ref             uuid,                 -- production_id si motif_type=production
  motif_libelle         text,                 -- texte libre ("Mise en place", "Repas personnel"...)
  -- Contexte production (nullable)
  fiche_ingredient_id   uuid,
  cle_etiquette         text,                 -- 'principal' ou index lots_supplementaires
  -- Validation
  valide_par_id         uuid,
  valide_par_nom        text,
  valide_par_initiales  text,
  valide_at             timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prelev_motif      ON prelevements(motif_type, motif_ref);
CREATE INDEX IF NOT EXISTS idx_prelev_statut     ON prelevements(statut);
CREATE INDEX IF NOT EXISTS idx_prelev_lot_recu   ON prelevements(lot_recu_scan_id);
CREATE INDEX IF NOT EXISTS idx_prelev_article    ON prelevements(article_id);
-- empeche de rapprocher 2 fois la meme etiquette prod active
CREATE UNIQUE INDEX IF NOT EXISTS uq_prelev_scan_actif
  ON prelevements(scan_prod_id)
  WHERE statut <> 'annule' AND scan_prod_id IS NOT NULL;

ALTER TABLE prelevements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS prelevements_anon_all ON prelevements;
CREATE POLICY prelevements_anon_all
  ON prelevements AS PERMISSIVE FOR ALL TO anon
  USING (true) WITH CHECK (true);

-- ------------------------------------------------------------
-- 2) Etiquettes ENFANT (reconditionnement d'une partie d'un lot)
--    IMPORTANT : ce n'est PAS une entree de stock. Aucun mouvement
--    ENTREE associe -> pas de lot fantome dans stock_par_lot.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS etiquettes_prelevement (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  etablissement            text NOT NULL,
  parent_scan_tracabilite_id uuid,           -- lot RECEPTIONNE d'origine
  article_id               uuid,
  produit                  text,
  lot_parent               text,
  dlc_origine              date,
  dlc_secondaire           date,             -- DLC apres ouverture/reconditionnement
  quantite                 numeric,
  unite                    text DEFAULT 'kg',
  numero_etiquette         text,             -- ex. PREL-0608-013 (genere)
  storage_path             text,             -- photo/PDF de l'etiquette imprimee (optionnel)
  prelevement_id           uuid,             -- lien vers prelevements
  stock_mouvement_id       uuid,
  cree_par_id              uuid,
  cree_par_nom             text,
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etiq_prelev_parent     ON etiquettes_prelevement(parent_scan_tracabilite_id);
CREATE INDEX IF NOT EXISTS idx_etiq_prelev_prelev     ON etiquettes_prelevement(prelevement_id);

ALTER TABLE etiquettes_prelevement ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS etiquettes_prelevement_anon_all ON etiquettes_prelevement;
CREATE POLICY etiquettes_prelevement_anon_all
  ON etiquettes_prelevement AS PERMISSIVE FOR ALL TO anon
  USING (true) WITH CHECK (true);

-- ------------------------------------------------------------
-- 3) Apprentissage (fondation auto-rapprochement futur)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rapprochement_apprentissage (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id          uuid NOT NULL,
  lot_ocr_normalise   text NOT NULL,   -- lot OCR de l'etiquette scannee, normalise
  lot_recu            text,            -- lot recu confirme
  lot_recu_scan_id    uuid,
  nb_confirmations    integer NOT NULL DEFAULT 0,
  nb_rejets           integer NOT NULL DEFAULT 0,
  derniere_decision   text,            -- valide | rejete
  etablissement       text NOT NULL,
  created_by_id       uuid,
  created_by_nom      text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_rappr_apprentissage
  ON rapprochement_apprentissage(article_id, lot_ocr_normalise, etablissement);
CREATE INDEX IF NOT EXISTS idx_rappr_apprentissage_article
  ON rapprochement_apprentissage(article_id);

ALTER TABLE rapprochement_apprentissage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rapprochement_apprentissage_anon_all ON rapprochement_apprentissage;
CREATE POLICY rapprochement_apprentissage_anon_all
  ON rapprochement_apprentissage AS PERMISSIVE FOR ALL TO anon
  USING (true) WITH CHECK (true);

-- ------------------------------------------------------------
-- 4) Colonnes d'audit de reouverture sur productions (Admin, exception)
-- ------------------------------------------------------------
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouvert_par_id   uuid;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouvert_par_nom  text;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouvert_at       timestamptz;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouverture_motif text;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS nb_reouvertures  integer NOT NULL DEFAULT 0;

-- ------------------------------------------------------------
-- 5) Verifications post-migration (lecture seule)
-- ------------------------------------------------------------
-- SELECT tablename, policyname FROM pg_policies
--   WHERE tablename IN ('prelevements','etiquettes_prelevement','rapprochement_apprentissage');
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name='productions' AND column_name LIKE 'rouvert%';

-- ============================================================
-- RAPPEL modele de mouvement (a respecter cote code) :
--   SORTIE : type='SORTIE', scan_tracabilite_id = lot_recu_scan_id (PARENT recu),
--            article_id, quantite, unite, source_table = motif_type mappe
--            ('production' ou 'sortie_manuelle'), source_id = motif_ref,
--            motif = motif_libelle.
--   ANNULATION (reouverture) : mouvement inverse type='ENTREE' meme lot/quantite,
--            motif = "Annulation prelevement (reouverture)".
--   Les seuls types autorises en base sont ENTREE et SORTIE.
-- ============================================================
