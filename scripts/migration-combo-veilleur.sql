-- ============================================================================
-- Migration : veilleur Combo (executee via MCP le 30/09/2026, gardee pour trace)
-- Table de journal + reveil nocturne pg_cron -> edge function combo-veilleur
-- Prerequis : extensions pg_cron et pg_net actives, secret COMBO_API_KEY
-- (Edge Functions -> Secrets), fonction supabase/functions/combo-veilleur deployee.
-- NB : la cle Authorization ci-dessous est la cle anon PUBLIQUE du projet
-- (la meme que dans js/planb-common.js) - ce n est pas un secret.
-- ============================================================================

CREATE TABLE IF NOT EXISTS combo_veilleur_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom             TEXT NOT NULL,
    etablissement   TEXT,
    statut          TEXT NOT NULL,           -- cree | a_verifier | doublon_supprime
    user_id         UUID,
    pin             TEXT,
    detail          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE combo_veilleur_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS combo_veilleur_log_anon_all ON combo_veilleur_log;
CREATE POLICY combo_veilleur_log_anon_all ON combo_veilleur_log
    AS PERMISSIVE FOR ALL TO anon
    USING (true) WITH CHECK (true);

-- Reveil bi-quotidien : 03h30 et 08h30 UTC (= 05h30/10h30 ete a Strasbourg)
-- Le passage du matin rattrape les changements de planning de derniere minute.
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'combo-veilleur-nightly') THEN
    PERFORM cron.unschedule('combo-veilleur-nightly');
  END IF;
END
$do$;

SELECT cron.schedule(
  'combo-veilleur-nightly',
  '30 3,8 * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/combo-veilleur',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb
  )
  $cron$
);

-- Verifications post-migration :
-- SELECT policyname FROM pg_policies WHERE tablename = 'combo_veilleur_log';  -- 1 ligne attendue
-- SELECT jobname, schedule FROM cron.job WHERE jobname = 'combo-veilleur-nightly';
