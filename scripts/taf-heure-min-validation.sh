#!/bin/bash
# TAF : heure minimale de validation (ex. nettoyages du soir pas avant 22:00, admin peut passer outre)
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add taf/index.html sw.js scripts/migration-heure-min-validation.sql scripts/taf-heure-min-validation.sh
git commit -m "TAF : heure minimale de validation par recurrence (nettoyages du soir Freddy pas avant 22h, admin peut passer outre) + bump SW v128

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
