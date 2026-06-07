#!/usr/bin/env bash
# ============================================
# Commit : garde-fou anti double-clic sur la generation de commandes + bump SW v33
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-anti-double-clic.sh
# IMPORTANT : on commit UNIQUEMENT approvisionnement/index.html + sw.js. briefing reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

git add approvisionnement/index.html sw.js scripts/commit-appro-anti-double-clic.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Appro: garde-fou anti double-clic sur generation commandes (evite les doublons) + bump SW v33"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
