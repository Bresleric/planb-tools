-- ============================================================================
-- Migration : synchro des pointages Combo (executee via MCP le 04/10/2026, gardee pour trace)
-- pg_cron -> edge function combo-pointages (supabase/functions/combo-pointages)
-- Recupere J-2 et J-1 (planning prevu + badgeages + heures retenues) dans
-- combo_pointages (lignes import_fichier_nom = 'api-combo').
-- Pas de nouvelle table : combo_pointages existe deja (RLS + policy anon OK).
-- NB : la cle Authorization ci-dessous est la cle anon PUBLIQUE du projet
-- (la meme que dans js/planb-common.js) - ce n est pas un secret.
-- ============================================================================

-- 03h45 et 08h45 UTC, juste apres le veilleur (03h30 / 08h30)
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'combo-pointages-sync') THEN
    PERFORM cron.unschedule('combo-pointages-sync');
  END IF;
END
$do$;

SELECT cron.schedule(
  'combo-pointages-sync',
  '45 3,8 * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/combo-pointages',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb,
    timeout_milliseconds := 60000
  )
  $cron$
);

-- Rattrapage ponctuel (fin EXCLUE) :
-- SELECT net.http_post(url := '.../functions/v1/combo-pointages?start=2026-09-01&end=2026-10-04', ...);

-- Verifications :
-- SELECT jobname, schedule FROM cron.job WHERE jobname = 'combo-pointages-sync';
-- SELECT etablissement, date_service, count(*), count(debut_pointe) FROM combo_pointages
--   WHERE import_fichier_nom = 'api-combo' GROUP BY 1, 2 ORDER BY 2 DESC;
