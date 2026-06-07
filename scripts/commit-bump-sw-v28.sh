#!/usr/bin/env bash
# ============================================
# Commit : bump service worker v28 (pour deployer l appro besoins sur les iPads)
# PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-bump-sw-v28.sh
# IMPORTANT : on commit UNIQUEMENT sw.js. briefing/index.html (autre session) reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

# Ajout EXPLICITE de sw.js seulement (+ ce script). Surtout pas de git add -A.
git add sw.js scripts/commit-bump-sw-v28.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Bump SW v28 pour deployer appro besoins tableau sur les iPads"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
