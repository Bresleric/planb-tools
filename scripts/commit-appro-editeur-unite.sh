#!/usr/bin/env bash
# ============================================
# Commit : editeur d unite inline dans Ingredients (corriger kg<->pce) + g/cL + bump SW v31
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-editeur-unite.sh
# IMPORTANT : on commit UNIQUEMENT approvisionnement/index.html + sw.js. briefing reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

git add approvisionnement/index.html sw.js scripts/commit-appro-editeur-unite.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Appro: editeur unite inline dans Ingredients (corriger kg/pce) + ajout g et cL + bump SW v31"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
