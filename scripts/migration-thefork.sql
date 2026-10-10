-- ============================================================================
-- Migration TheFork — reservations Freddy (10/10/2026)
-- STATUT : DEJA APPLIQUEE en base via MCP le 10/10/2026 (en plusieurs morceaux).
-- Ce fichier est la TRACE repo. Idempotent : rejouable sans risque.
--
-- Contenu :
--   1. Table reservations_thefork (donnees clients minimales : nom,
--      allergies, commentaire — ni telephone ni email)
--   2. RLS + policy pbt_session (AUCUNE policy anon — modele securite 08-10/10)
--   3. Fonctions pbt_service_config_get/set : cache du jeton OAuth TheFork
--      dans pbt_private.config, EXECUTE reserve au service_role (edge functions)
--
-- Le cron horaire est programme separement (job 'thefork-sync-horaire') :
--   SELECT cron.schedule('thefork-sync-horaire', '7 * * * *', $$ ... net.http_post
--     vers https://dzrherfavgiuygnimtux.supabase.co/functions/v1/thefork-sync ... $$);
-- ============================================================================

-- 1. Table ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reservations_thefork (
  thefork_id    text PRIMARY KEY,
  etablissement text NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
  date          date NOT NULL,
  heure         time,
  service       text CHECK (service IN ('midi', 'soir')),
  couverts      integer,
  statut        text,
  nom_client    text,
  allergies     text,
  commentaire   text,
  payload       jsonb,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_resa_tf_etab_date ON reservations_thefork (etablissement, date);

-- 2. RLS : acces reserve aux sessions applicatives ---------------------------
ALTER TABLE reservations_thefork ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON reservations_thefork;
CREATE POLICY pbt_session ON reservations_thefork FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

-- 3. Cache de configuration service (jeton OAuth TheFork) --------------------
CREATE TABLE IF NOT EXISTS pbt_private.config (
  cle    text PRIMARY KEY,
  valeur text
);

CREATE OR REPLACE FUNCTION public.pbt_service_config_get(p_cle text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT valeur FROM pbt_private.config WHERE cle = p_cle;
$$;

CREATE OR REPLACE FUNCTION public.pbt_service_config_set(p_cle text, p_valeur text)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  INSERT INTO pbt_private.config (cle, valeur) VALUES (p_cle, p_valeur)
  ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
$$;

-- EXECUTE reserve au service_role : PostgREST n expose pas pbt_private,
-- et ni anon ni authenticated ne doivent lire le jeton.
REVOKE ALL ON FUNCTION public.pbt_service_config_get(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pbt_service_config_set(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pbt_service_config_get(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.pbt_service_config_set(text, text) TO service_role;

-- Verification post-migration :
--   SELECT tablename, policyname FROM pg_policies WHERE tablename = 'reservations_thefork';
