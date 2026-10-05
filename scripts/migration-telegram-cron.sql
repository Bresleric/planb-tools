-- ============================================================================
-- Cron du digest Telegram (a executer UNE FOIS le bot configure :
-- secret TELEGRAM_BOT_TOKEN pose + chat admin enregistre via register)
--
-- Toutes les 30 minutes, la fonction telegram-notif compile les nouveaux
-- besoins appro et demandes entre maisons depuis le dernier digest, et
-- envoie UN message Telegram a Eric seulement s il y a du neuf.
--
-- NB : la cle Authorization ci-dessous est la cle anon PUBLIQUE du projet
-- (deja presente dans le code front et dans le cron combo-veilleur).
-- ============================================================================

SELECT cron.schedule(
  'telegram-digest',
  '*/30 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/telegram-notif',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb,
    body := '{"action":"digest"}'::jsonb
  );
  $$
);

-- Verification : SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'telegram-digest';
-- Suppression  : SELECT cron.unschedule('telegram-digest');
