-- ============================================================================
-- Migration : synchros Combo a 2h du matin (demande Eric du 06/10/2026)
-- (executee via MCP le 06/10/2026, gardee pour trace)
-- Remplace les horaires de migration-combo-veilleur.sql et migration-combo-pointages-cron.sql.
-- pg_cron tourne en GMT (cron.timezone = GMT, sans changement d heure) : on lance
-- a 0h ET 1h GMT pour qu un passage tombe TOUJOURS a 2h a Strasbourg
-- (ete : 2h et 3h ; hiver : 1h et 2h). Les deux fonctions sont idempotentes.
-- Passage de 9h GMT (11h ete / 10h hiver) conserve : rattrape les corrections
-- faites dans Combo par les managers en debut de matinee.
-- Veilleur a :00, pointages a :05.
-- ============================================================================
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'combo-veilleur-nightly') THEN PERFORM cron.unschedule('combo-veilleur-nightly'); END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'combo-pointages-sync') THEN PERFORM cron.unschedule('combo-pointages-sync'); END IF;
END
$do$;

SELECT cron.schedule('combo-veilleur-nightly', '0 0,1,9 * * *', $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/combo-veilleur',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb
  )
$cron$);

SELECT cron.schedule('combo-pointages-sync', '5 0,1,9 * * *', $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/combo-pointages',
    body := '{}'::jsonb,
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb,
    timeout_milliseconds := 60000
  )
$cron$);

-- Verification : SELECT jobname, schedule FROM cron.job WHERE jobname LIKE 'combo%';
