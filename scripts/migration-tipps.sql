-- ============================================================================
-- Module Tipps : partage du pot commun des pourboires (03/11/2026)
-- Idempotent : rejouable sans risque.
--
-- Regles (decisions Eric 03/11/2026) :
--   - chaque soir la salle saisit dans le controle de caisse le montant des
--     Tipps qui vont au pot commun (nouveau champ tipps_pot_commun)
--   - partage JOUR PAR JOUR au prorata des heures Combo validees du jour,
--     ponderees par equipe : salle 100 %, cuisine 75 %, plonge 30 %
--   - minoration en % par salarie, saisie SEMAINE PAR SEMAINE ; la part
--     retenue est redistribuee aux autres membres de la meme equipe
--   - la cloture fige le detail de la semaine (snapshot) pour la paie
-- ============================================================================

-- 1. Saisie du pot commun dans le controle de caisse
--    (pas de nouvelle table -> la policy pbt_session de caisse_controle s applique)
ALTER TABLE caisse_controle ADD COLUMN IF NOT EXISTS tipps_pot_commun numeric(10,2) DEFAULT 0;

-- 2. Minorations de la semaine (cle salarie = nom Combo, toujours present)
CREATE TABLE IF NOT EXISTS tipps_minorations (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  etablissement text NOT NULL,
  semaine_debut date NOT NULL,                 -- lundi de la semaine
  salarie_nom text NOT NULL,                   -- combo_pointages.collaborateur_nom_combo
  pct numeric(5,2) NOT NULL CHECK (pct >= 0 AND pct <= 100),
  motif text,
  saisi_par_id uuid,
  saisi_par_nom text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (etablissement, semaine_debut, salarie_nom)
);

-- 3. Clotures de semaine (detail fige du partage)
CREATE TABLE IF NOT EXISTS tipps_clotures (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  etablissement text NOT NULL,
  semaine_debut date NOT NULL,
  total_pot numeric(10,2) NOT NULL DEFAULT 0,
  detail jsonb NOT NULL,                       -- { salaries: [...], jours: [...], alertes: [...] }
  cloture_par_id uuid,
  cloture_par_nom text,
  cloture_le timestamptz DEFAULT now(),
  UNIQUE (etablissement, semaine_debut)
);

-- 4. RLS : modele pbt_session (aucune policy anon)
ALTER TABLE tipps_minorations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON tipps_minorations;
CREATE POLICY pbt_session ON tipps_minorations FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

ALTER TABLE tipps_clotures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON tipps_clotures;
CREATE POLICY pbt_session ON tipps_clotures FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

-- Verification :
--   SELECT tablename, policyname FROM pg_policies WHERE tablename IN ('tipps_minorations', 'tipps_clotures');
--   SELECT column_name FROM information_schema.columns WHERE table_name = 'caisse_controle' AND column_name = 'tipps_pot_commun';
