#!/usr/bin/env bash
# Fix TAF : si un libelle est tape mais que la ligne « + À créer » na pas pris le toucher,
# le bouton Créer la tâche cree quand meme la tache en À créer. Bump SW v122.
set -euo pipefail
cd ~/planb-tools
BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
git add taf/index.html sw.js scripts/fix-taf-creer-filet-securite.sh
git commit -m "TAF : creer la tache A creer avec le libelle tape meme sans toucher la ligne orange + bump SW v122

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin "$BRANCH"
echo "=== OK ==="
