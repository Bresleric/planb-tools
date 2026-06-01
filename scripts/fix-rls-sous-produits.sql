-- ============================================================
-- Fix RLS : fiches_techniques_sous_produits (oubli migration Phase 1)
-- La table avait RLS active mais AUCUNE policy -> tout INSERT/SELECT bloque
-- pour le role anon ("new row violates row-level security policy").
-- On reproduit EXACTEMENT le pattern de la table soeur qui marche
-- (fiches_techniques_actions_post : policy ALL, role anon, USING true / WITH CHECK true).
-- Idempotent : DROP IF EXISTS puis CREATE (CREATE POLICY IF NOT EXISTS n existe pas en Postgres).
-- ============================================================

-- 1) S assurer que RLS est active (coherent avec les tables soeurs)
ALTER TABLE fiches_techniques_sous_produits ENABLE ROW LEVEL SECURITY;

-- 2) Policy permissive ALL pour le role anon (calquee sur ftap_anon_all)
DROP POLICY IF EXISTS ftsp_anon_all ON fiches_techniques_sous_produits;
CREATE POLICY ftsp_anon_all
  ON fiches_techniques_sous_produits
  AS PERMISSIVE
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- 3) Verification : la policy doit apparaitre, identique aux soeurs
SELECT tablename, policyname, cmd, permissive, roles::text, qual::text, with_check::text
FROM pg_policies
WHERE tablename = 'fiches_techniques_sous_produits';
