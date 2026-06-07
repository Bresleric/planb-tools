#!/usr/bin/env bash
# ============================================
# Commit : anti-doublon besoins (module Approvisionnement)
# PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-besoins-anti-doublon.sh
# ============================================
set -euo pipefail

cd ~/planb-tools

# 1. Securite branche
BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

# 2. Synchro upstream avant de committer (refuse si non fast-forward)
git pull --ff-only origin "$BRANCH"
echo ""

# 3. Etat du repo avant commit
git status
echo ""

# 4. Ajout des seuls fichiers concernes (on NE touche pas aux nombreux fichiers non suivis)
git add approvisionnement/index.html \
        sw.js \
        scripts/commit-appro-besoins-anti-doublon.sh

# 5. Commit (message sans apostrophe)
git commit -m "Appro: empeche les besoins en doublon (meme produit une seule fois) + bump SW v23"

# 6. Push sur la branche active
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
