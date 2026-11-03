-- ============================================================================
-- Tipps reserve a l administrateur (decision Eric 03/11/2026)
-- Idempotent. Remplace la policy pbt_session par une policy pbt_admin sur les
-- tables du module : seule une session PBT de role admin peut lire/ecrire.
-- (caisse_controle.tipps_pot_commun reste saisissable par l equipe de salle.)
-- ============================================================================
DROP POLICY IF EXISTS pbt_session ON tipps_minorations;
DROP POLICY IF EXISTS pbt_admin ON tipps_minorations;
CREATE POLICY pbt_admin ON tipps_minorations FOR ALL TO authenticated
  USING ((select public.pbt_role()) = 'admin') WITH CHECK ((select public.pbt_role()) = 'admin');

DROP POLICY IF EXISTS pbt_session ON tipps_clotures;
DROP POLICY IF EXISTS pbt_admin ON tipps_clotures;
CREATE POLICY pbt_admin ON tipps_clotures FOR ALL TO authenticated
  USING ((select public.pbt_role()) = 'admin') WITH CHECK ((select public.pbt_role()) = 'admin');

-- Verification :
--   SELECT tablename, policyname, qual FROM pg_policies WHERE tablename IN ('tipps_minorations', 'tipps_clotures');
