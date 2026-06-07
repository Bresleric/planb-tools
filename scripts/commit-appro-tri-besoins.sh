#!/usr/bin/env bash
# ============================================
# Commit : tri sur les colonnes du tableau des besoins + bump SW v30
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-tri-besoins.sh
# IMPORTANT : on commit UNIQUEMENT approvisionnement/index.html + sw.js.
#   briefing/index.html (autre session) reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

# Ajout EXPLICITE (jamais git add -A)
git add approvisionnement/index.html sw.js scripts/commit-appro-tri-besoins.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Appro besoins: tri cliquable sur les colonnes du tableau + bump SW v30"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
