#!/bin/bash
# Admin : onglet Jeton L Addition (renouvellement sans SQL Editor) + rappel Telegram avant expiration (SW v141)
set -e
cd ~/planb-tools
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git status --short admin/index.html sw.js supabase/functions/laddition-live/index.ts supabase/functions/telegram-notif/index.ts scripts/migration-laddition-jeton-admin.sql scripts/laddition-jeton-admin.sh
echo "Commit et push sur $BRANCHE ? (o/n)"
read -r REPLY
if [ "$REPLY" != "o" ]; then echo "Annule."; exit 0; fi
git add admin/index.html sw.js supabase/functions/laddition-live/index.ts supabase/functions/telegram-notif/index.ts scripts/migration-laddition-jeton-admin.sql scripts/laddition-jeton-admin.sh
git commit -m "Admin : onglet Jeton L Addition (date du dernier jeton, age, expiration estimee, etat de la synchro, collage du refreshToken via RPC admin sans jamais afficher la valeur, test immediat de la synchro) + rappel Telegram quotidien a partir du 15e jour (cron laddition-jeton-rappel) + alerte d echec renvoyant vers Admin au lieu du SQL Editor + bump SW v141

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push origin "$BRANCHE"
echo "Pousse. Publication GitHub Pages en cours (1 a 2 minutes)."
