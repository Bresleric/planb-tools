#!/bin/bash
# TAF : filtre par collaborateur pour les administrateurs
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add taf/index.html sw.js scripts/taf-filtre-collaborateur-admin.sh
git commit -m "TAF : filtre Personne pour les administrateurs (taches attribuees ou faites par un collaborateur, non attribuees) + bump SW v127

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
