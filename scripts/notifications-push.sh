#!/bin/bash
# Notifications push : moteur de regles + SW reellement enregistre (12/10/2026)
# Commit prepare par la session Claude Code apres OK d Eric.
set -e
cd ~/planb-tools

BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"

git add index.html sw.js manifest.json \
        supabase/functions/notif-push/index.ts \
        scripts/migration-notifications-push.sql \
        scripts/migration-notifications-cron.sql \
        scripts/notifications-push.sh

git commit -F - <<'MSG'
Notifications push : moteur de regles + service worker enfin actif

- index.html : enregistrement du VRAI sw.js (l ancien SW inline en blob
  etait refuse en silence), manifest.json reel, bouton cloche pour activer
  les notifications sur chaque iPad, synchro silencieuse des abonnements
- manifest.json : scope et start_url relatifs (site sous /planb-tools/)
- Edge function notif-push : cle publique VAPID, test par appareil,
  renouvellement d abonnement, tick 5 min (evenements -> anti-doublon ->
  push par etablissement -> journal -> recap Telegram admin)
- Moteur SQL notif_evenements() + tables notification_regles et
  notifications_envoyees (RLS pbt_session) + 8 regles validees
- Cron notif-push-tick dans un fichier SQL separe, a activer apres test
- SW v114

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01E7K7vzuFp7sS9H2BM6DN2c
MSG

git push origin "$BRANCHE"
echo "OK - pousse sur $BRANCHE"
