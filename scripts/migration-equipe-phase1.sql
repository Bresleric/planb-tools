-- ============================================================================
-- Module Equipe (Planning + Pointage) - Phase 1 : contrats + validation des heures
-- Date : 03/11/2026 - bascule Combo -> PlanB-Tools au 01/01/2027 (paie Payfit)
-- ----------------------------------------------------------------------------
-- Idempotent : peut etre relance sans risque.
--
-- 1. Table rh_contrats : le strict necessaire pour planifier et preparer la paie
--    (type de contrat, heures hebdo, dates, matricule Payfit). Les donnees RH
--    sensibles (NIR, adresse, IBAN, salaire) restent dans Payfit, PAS ici.
--    Une ligne par contrat : un avenant = on termine l ancien, on en cree un nouveau.
--    Lecture : toute session PBT (le planning a besoin des heures contrat).
--    Ecriture : admin seulement.
--
-- 2. pointage_periodes_travail : ajout du niveau VALIDE (heures retenues par le
--    manager). Les heures badgees (debut_service / fin_service) ne sont JAMAIS
--    modifiees par la validation : on garde la trace brute a cote du retenu.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. rh_contrats
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rh_contrats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  equipe TEXT NOT NULL CHECK (equipe IN ('salle', 'cuisine', 'plonge', 'autre')),
  type_contrat TEXT NOT NULL CHECK (type_contrat IN ('cdi', 'cdd', 'extra', 'apprentissage', 'stage')),
  heures_hebdo NUMERIC NOT NULL DEFAULT 0 CHECK (heures_hebdo >= 0 AND heures_hebdo <= 48),
  date_debut DATE NOT NULL,
  date_fin DATE,                          -- NULL = en cours (CDI ou CDD sans fin saisie)
  matricule_payfit TEXT,                  -- identifiant salarie dans Payfit (fichier d import)
  source TEXT NOT NULL DEFAULT 'saisie' CHECK (source IN ('saisie', 'import_combo')),
  notes TEXT,
  saisi_par_id UUID,
  saisi_par_nom TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

CREATE INDEX IF NOT EXISTS idx_rh_contrats_user ON rh_contrats(user_id);
CREATE INDEX IF NOT EXISTS idx_rh_contrats_etab ON rh_contrats(etablissement);

COMMENT ON TABLE rh_contrats IS
  'Contrats de travail (minimum utile au planning et a la paie Payfit). Une ligne par contrat ou avenant. Donnees RH sensibles : dans Payfit uniquement.';

ALTER TABLE rh_contrats ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON rh_contrats;
DROP POLICY IF EXISTS pbt_session_lecture ON rh_contrats;
CREATE POLICY pbt_session_lecture ON rh_contrats FOR SELECT TO authenticated
  USING ((select public.pbt_session_ok()));
DROP POLICY IF EXISTS pbt_admin ON rh_contrats;
CREATE POLICY pbt_admin ON rh_contrats FOR ALL TO authenticated
  USING ((select public.pbt_role()) = 'admin') WITH CHECK ((select public.pbt_role()) = 'admin');

-- ---------------------------------------------------------------------------
-- 2. Niveau VALIDE sur pointage_periodes_travail
-- ---------------------------------------------------------------------------
ALTER TABLE pointage_periodes_travail ADD COLUMN IF NOT EXISTS debut_valide TIMESTAMPTZ;
ALTER TABLE pointage_periodes_travail ADD COLUMN IF NOT EXISTS fin_validee TIMESTAMPTZ;
ALTER TABLE pointage_periodes_travail ADD COLUMN IF NOT EXISTS pauses_validees_minutes INTEGER;
ALTER TABLE pointage_periodes_travail ADD COLUMN IF NOT EXISTS duree_validee_minutes INTEGER
  GENERATED ALWAYS AS (
    CASE
      WHEN debut_valide IS NOT NULL AND fin_validee IS NOT NULL
      THEN EXTRACT(EPOCH FROM (fin_validee - debut_valide))::INTEGER / 60 - COALESCE(pauses_validees_minutes, 0)
      ELSE NULL
    END
  ) STORED;

COMMENT ON COLUMN pointage_periodes_travail.debut_valide IS
  'Heure de debut RETENUE par le manager (source paie). debut_service reste l heure badgee brute.';

-- ---------------------------------------------------------------------------
-- Verifications (a lancer apres) :
--   SELECT tablename, policyname, cmd FROM pg_policies WHERE tablename = 'rh_contrats';
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'pointage_periodes_travail' AND column_name LIKE '%valid%';
-- ---------------------------------------------------------------------------
