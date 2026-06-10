#!/usr/bin/env bash
# ============================================
# Commit : filet de securite est_principal a la sauvegarde des FT + bump SW v36
# Module Production — PlanB Tools — 10/06/2026
# A lancer : bash scripts/commit-production-filet-est-principal.sh
# IMPORTANT : on commit UNIQUEMENT production/index.html + sw.js. briefing reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

git add production/index.html sw.js scripts/commit-production-filet-est-principal.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Production: filet de securite est_principal a la sauvegarde des FT (ne perd plus le flag scan si une ligne arrive sans le champ) + bump SW v36"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
