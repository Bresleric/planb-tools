#!/bin/bash
# TAF : un nettoyage du soir est attribue automatiquement a celui qui part le dernier (et non a celui qui arrive le premier)
cd ~/planb-tools || exit 1
BRANCHE=$(git branch --show-current)
echo "Branche active : $BRANCHE"
git add taf/index.html sw.js scripts/taf-nettoyage-soir-dernier-parti.sh
git commit -m "TAF : nettoyage du soir attribue a celui qui part le dernier selon le planning + bump SW v125

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCHE"
