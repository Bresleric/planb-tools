-- ============================================================================
-- Migration L Addition Live -> Pilotage (12/10/2026)
-- Idempotent : rejouable sans risque.
--
-- Contenu :
--   1. laddition_live        : etat en direct par etablissement (1 ligne / etab)
--   2. laddition_ventes_jour : totaux + ventes produits par jour (historique)
--   3. laddition_ruptures    : heure ou un article du stock caisse tombe a 0
--   4. RLS + policy pbt_session (AUCUNE policy anon)
--   5. Cron toutes les 30 min, 8h-23h30 UTC (= 10h-1h30 Paris en ete,
--      9h-0h30 en hiver) -> edge function laddition-live
--
-- Le jeton L Addition (refreshToken) se colle A PART, par Eric, dans le
-- SQL Editor (jamais dans le repo) :
--   SELECT public.pbt_service_config_set('laddition_refresh_token', 'COLLER_ICI');
--   SELECT public.pbt_service_config_set('laddition_access_token', '');
-- ============================================================================

-- 1. Etat en direct ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS laddition_live (
  etablissement   text PRIMARY KEY CHECK (etablissement IN ('freddy', 'liesel')),
  date_service    date,
  service_ouvert  timestamptz,
  maj_caisse      timestamptz,          -- derniere photo envoyee par la caisse
  synchro_le      timestamptz,          -- dernier passage reussi de la synchro
  ca              numeric(10,2),
  encaisse        numeric(10,2),
  remise          numeric(10,2),
  offert          numeric(10,2),
  couverts        integer,
  additions       integer,
  moyenne_couvert numeric(10,2),
  ticket_moyen    numeric(10,2),
  annulations     jsonb,
  serveurs        jsonb,                -- [{nom, ca, couverts, additions, remise, offert}]
  salles          jsonb,                -- [{nom, ca, remise}]
  produits        jsonb,                -- [{nom, qte, ca}]
  options         jsonb,
  menus           jsonb,
  stocks          jsonb,                -- [{nom, cle, qte, qte_ouv}] (cle = "nom #2" si doublon)
  evolution       jsonb,                -- [{t, ca, enc}]
  erreur          text,
  erreur_le       timestamptz
);

-- 2. Historique des ventes par jour -----------------------------------------
CREATE TABLE IF NOT EXISTS laddition_ventes_jour (
  etablissement text NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
  date_service  date NOT NULL,
  ca            numeric(10,2),
  encaisse      numeric(10,2),
  couverts      integer,
  additions     integer,
  remise        numeric(10,2),
  offert        numeric(10,2),
  produits      jsonb,
  menus         jsonb,
  maj_le        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (etablissement, date_service)
);

-- 3. Ruptures horodatees ----------------------------------------------------
CREATE TABLE IF NOT EXISTS laddition_ruptures (
  id            bigserial PRIMARY KEY,
  etablissement text NOT NULL CHECK (etablissement IN ('freddy', 'liesel')),
  date_service  date NOT NULL,
  produit       text NOT NULL,
  epuise_vers   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (etablissement, date_service, produit)
);

-- 4. RLS : acces reserve aux sessions applicatives ---------------------------
ALTER TABLE laddition_live ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON laddition_live;
CREATE POLICY pbt_session ON laddition_live FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

ALTER TABLE laddition_ventes_jour ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON laddition_ventes_jour;
CREATE POLICY pbt_session ON laddition_ventes_jour FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

ALTER TABLE laddition_ruptures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON laddition_ruptures;
CREATE POLICY pbt_session ON laddition_ruptures FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

-- 5. Cron toutes les 30 min ---------------------------------------------------
-- NB : la cle Authorization ci-dessous est la cle anon PUBLIQUE du projet
-- (la meme que dans js/planb-common.js) - ce n est pas un secret.
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'laddition-live-30min') THEN
    PERFORM cron.unschedule('laddition-live-30min');
  END IF;
END
$do$;

SELECT cron.schedule(
  'laddition-live-30min',
  '*/30 8-23 * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/laddition-live',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb,
    timeout_milliseconds := 60000
  )
  $cron$
);

-- Verifications :
--   SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'laddition_%';
--   SELECT jobname, schedule FROM cron.job WHERE jobname = 'laddition-live-30min';
--   SELECT etablissement, date_service, ca, couverts, synchro_le, erreur FROM laddition_live;
