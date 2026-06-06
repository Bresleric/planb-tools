#!/usr/bin/env bash
# ============================================
# Commit : onglet Receptions (Phase 1) module Approvisionnement
# PlanB Tools — 06/06/2026
# A lancer : bash scripts/commit-appro-receptions.sh
# ============================================
set -euo pipefail

cd ~/planb-tools

# 1. Securite branche : on montre ou on est, pas de push a l aveugle sur main
BRANCH=$(git branch --show-current)
echo "Branche active : $BRANCH"
echo ""

# 2. Etat du repo avant commit
git status
echo ""

# 3. Ajout des fichiers touches
git add approvisionnement/index.html \
        sw.js \
        scripts/migration-appro-receptions.sql \
        scripts/commit-appro-receptions.sh

# 4. Commit (message sans apostrophe, conforme au playbook)
git commit -m "Appro: onglet Receptions Phase 1 (validation manuelle) + bump SW v21"

# 5. Push sur la branche active
git push origin "$BRANCH"

echo ""
echo "Termine. Pousse sur la branche : $BRANCH"
