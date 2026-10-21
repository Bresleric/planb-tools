#!/usr/bin/env bash
# Fix TAF onglet Creer : toucher une equipe (Cuisine, Salle...) effacait la tache deja choisie. Bump SW v123.
set -euo pipefail
cd ~/planb-tools
BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
git add taf/index.html sw.js scripts/fix-taf-equipe-efface-tache.sh
git commit -m "TAF : choisir une equipe dans Creer n efface plus la tache choisie + bump SW v123

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCH"
echo "=== OK ==="
