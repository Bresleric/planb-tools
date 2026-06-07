#!/usr/bin/env bash
# ============================================
# Commit : besoins en tableau (roulette qte 1-40) + outil rattachement item->fournisseur
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-besoins-tableau.sh
# IMPORTANT : on commit UNIQUEMENT approvisionnement/index.html.
#   briefing/index.html et sw.js sont modifies par une AUTRE session -> on n y touche pas.
# ============================================
set -euo pipefail

cd ~/planb-tools

# 1. Securite branche
BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

# 2. Etat du repo (pour controle visuel)
git status
echo ""

# 3. Ajout EXPLICITE du seul fichier appro (+ ce script). Surtout pas de git add -A.
git add approvisionnement/index.html scripts/commit-appro-besoins-tableau.sh

echo "=== Fichiers stages ==="
git diff --cached --name-only
echo ""

# 4. Commit (message sans apostrophe)
git commit -m "Appro besoins: tableau avec roulette quantite 1-40 + outil rattachement item fournisseur + creation item admin depuis recherche"

# 5. Push sur la branche active
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
echo "NB : sw.js n a PAS ete bumpe (occupe par la session briefing). Le refresh PWA des iPads se fera quand le bump v27 du briefing sera pousse."
