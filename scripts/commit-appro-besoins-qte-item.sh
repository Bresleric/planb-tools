#!/usr/bin/env bash
# ============================================
# Commit : besoins (qte editable apres validation) + creation item admin rapide
# Module Approvisionnement — PlanB Tools — 07/06/2026
# A lancer : bash scripts/commit-appro-besoins-qte-item.sh
# ============================================
set -euo pipefail

cd ~/planb-tools

# 1. Securite branche
BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

# 2. Synchro upstream (refuse si non fast-forward)
git pull --ff-only origin "$BRANCH"
echo ""

# 3. Etat avant commit
git status
echo ""

# 4. Ajout des seuls fichiers concernes
git add approvisionnement/index.html \
        sw.js \
        scripts/commit-appro-besoins-qte-item.sh

# 5. Commit (message sans apostrophe)
git commit -m "Appro besoins: quantite editable apres validation + creation item admin rapide + flux dans modale ingredient + bump SW v26"

# 6. Push
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
