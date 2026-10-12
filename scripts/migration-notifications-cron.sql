-- ============================================================================
-- Notifications push — CRON (a activer en DERNIER, apres le test sur iPad)
-- Toutes les 5 minutes, 5h-23h UTC : la fonction notif-push calcule les
-- evenements (notif_evenements) et pousse vers les tablettes + Telegram.
-- La cle Authorization est la cle anon PUBLIQUE du projet (pas un secret).
-- ============================================================================
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notif-push-tick') THEN
    PERFORM cron.unschedule('notif-push-tick');
  END IF;
END
$do$;

SELECT cron.schedule(
  'notif-push-tick',
  '*/5 5-23 * * *',
  $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/notif-push',
    body := '{"action": "tick"}'::jsonb,
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb,
    timeout_milliseconds := 60000
  )
  $cron$
);

-- Verification : SELECT jobname, schedule FROM cron.job WHERE jobname = 'notif-push-tick';
