#!/usr/bin/env bash
# ============================================
# Commit : Service Worker en strategie RESEAU D'ABORD (network-first) + bump SW v37
# PlanB Tools — 10/06/2026
# A lancer : bash scripts/commit-sw-network-first.sh
# IMPORTANT : on commit UNIQUEMENT sw.js. briefing/index.html (autre session) reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

git add sw.js scripts/commit-sw-network-first.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "SW: strategie reseau d abord (network-first) pour charger toujours la derniere version + bump v37"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
