#!/bin/bash
# Commit : impression etiquette 3 taps (navigator.share au lieu ouverture PDF Safari)
# A lancer depuis ~/planb-tools/ avec : bash scripts/commit-impression-3taps.sh
set -e

cd "$(dirname "$0")/.."

echo "Branche active :"
git branch --show-current
echo "---"

git add production/index.html sw.js scripts/commit-impression-3taps.sh

git commit -m "feat(production): impression etiquette 3 taps via navigator.share

Remplace ouverture du PDF dans Safari par navigator.share() avec le PDF
en piece jointe : la feuille de partage iOS souvre directement (2 taps en
moins). jsPDF est prechargé a louverture de lapercu pour que share() reste
dans le geste utilisateur (contrainte iOS). Fallback ouverture Safari
conserve pour les appareils sans canShare(files). Applique au flux mono et
au flux multi sous-produits. PDF 89x62 inchangé. CACHE_NAME v15 -> v16."

git push origin main

echo "---"
echo "Push effectue sur main."
