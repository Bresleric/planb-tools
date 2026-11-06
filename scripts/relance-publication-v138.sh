#!/bin/bash
# Relance la publication GitHub Pages : aucun build lance pour le commit 18f959f (05/11/2026).
# Usage : bash ~/planb-tools/scripts/relance-publication-v138.sh
set -e
cd "$HOME/planb-tools"
BRANCHE=$(git branch --show-current)
echo "==> Branche active : $BRANCHE"
if [ "$BRANCHE" != "main" ]; then echo "STOP : on attendait la branche main."; exit 1; fi
if ! git diff --cached --quiet; then echo "STOP : des fichiers sont deja prepares. Rien n est commite."; exit 1; fi
git pull --ff-only
git add scripts/relance-publication-v138.sh
git commit -F - <<'MSG'
Relance publication GitHub Pages : aucun build lance pour le commit 18f959f (onglet Pointages, SW v138)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git push origin "$BRANCHE"
echo "==> Termine. Compter 1 a 2 minutes."
