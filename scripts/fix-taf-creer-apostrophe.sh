#!/usr/bin/env bash
# Fix TAF : le bouton « + À créer » ne reagissait pas quand le libelle
# tape contenait une apostrophe (ex. Pâte à l'ail). Bump SW v121.
set -euo pipefail
cd ~/planb-tools
BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
git add taf/index.html sw.js scripts/fix-taf-creer-apostrophe.sh
git commit -m "TAF : fix creation tache A creer quand le libelle contient une apostrophe + bump SW v121

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCH"
echo "=== OK ==="
