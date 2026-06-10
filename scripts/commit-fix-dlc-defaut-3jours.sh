#!/usr/bin/env bash
# ============================================
# Commit : fix DLC par defaut +3 jours (mode multi sous-produits) TAF + Production + bump SW v38
# PlanB Tools — 10/06/2026
# A lancer : bash scripts/commit-fix-dlc-defaut-3jours.sh
# IMPORTANT : on commit UNIQUEMENT taf/index.html, production/index.html et sw.js.
#   briefing/index.html (autre session) reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

git add taf/index.html production/index.html sw.js scripts/commit-fix-dlc-defaut-3jours.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Fix DLC: defaut +3 jours au lieu de +1 sur les productions multi sous-produits (TAF et Production) + bump SW v38"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
