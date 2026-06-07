#!/usr/bin/env bash
# ============================================
# Commit : generation commandes -> marquage rouge + rattachement inline des besoins sans fournisseur
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-gen-sans-fournisseur.sh
# IMPORTANT : on commit UNIQUEMENT approvisionnement/index.html.
#   Les 16 autres fichiers + sw.js (feature mode dev admin, autre session) restent non commites.
# ============================================
set -euo pipefail

cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

git status
echo ""

# Ajout EXPLICITE du seul fichier appro (+ ce script). Surtout pas de git add -A.
git add approvisionnement/index.html scripts/commit-appro-gen-sans-fournisseur.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

git commit -m "Appro commandes: marquage rouge des besoins sans fournisseur + rattachement inline a la generation"
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
echo "NB : sw.js non bumpe par moi. Le refresh PWA viendra avec le v29 (mode dev admin) quand l autre session le poussera."
