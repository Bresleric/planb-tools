#!/bin/bash
# TAF : fin des doublons de taches recurrentes + un collaborateur peut cocher les taches de son equipe
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add taf/index.html sw.js scripts/taf-doublons-recurrences-cochage-equipe.sh
git commit -m "TAF : fin des doublons de taches recurrentes a chaque changement de date + un collaborateur peut cocher les taches de son equipe + bump SW v126

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
