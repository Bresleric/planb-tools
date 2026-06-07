#!/usr/bin/env bash
# ============================================
# Commit : fix commandes non enregistrees (champ parasite appro_fournisseurs) + visibilite/historique
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-fix-commandes.sh
# IMPORTANT : on commit UNIQUEMENT approvisionnement/index.html + sw.js. briefing reste non commite.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

git add approvisionnement/index.html sw.js scripts/commit-appro-fix-commandes.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Appro fix: commandes non enregistrees (retrait champ parasite appro_fournisseurs + check erreurs) + besoins non perdus si sans prix + historique commandes recues/annulees + bump SW v32"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
