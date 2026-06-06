#!/usr/bin/env bash
# ============================================
# Commit : migration flux de reception appro_ingredients
# Module Approvisionnement — PlanB Tools — 06/06/2026
# A lancer : bash scripts/commit-appro-categorie-flux.sh
# ============================================
set -euo pipefail

cd ~/planb-tools

# 1. Securite branche : on montre ou on est, on ne push pas a l aveugle sur main
BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

# 2. Etat du repo avant commit
git status
echo ""

# 3. Ajout du seul fichier de migration (le .sh n a pas besoin d etre versionne,
#    on l ajoute quand meme pour garder la trace cote repo)
git add scripts/migration-appro-categorie-flux.sql scripts/commit-appro-categorie-flux.sh

# 4. Commit (message sans apostrophe, conforme au playbook)
git commit -m "Appro: ajout categorie_flux (scan vs validation) sur appro_ingredients"

# 5. Push sur la branche active (PAS de push origin main en dur)
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
