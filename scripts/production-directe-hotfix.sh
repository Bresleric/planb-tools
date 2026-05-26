#!/bin/bash
# ============================================================
# Hotfix Production directe — defensive wrappers
# Tout le code top-level executable est desormais dans des
# try/catch pour qu'une erreur runtime cote production directe
# ne puisse pas casser init() (et donc tous les boutons).
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="
echo ""

git add production/index.html scripts/production-directe-hotfix.sh

echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/production-directe-hotfix.sh
echo ""

git commit -m "fix(production): defensive try/catch around production directe

Probleme : apres le push de la feature production directe, plusieurs
boutons du module Production (FAB +, Portail, Deconnexion, Fiches)
ne repondaient plus. Probablement un runtime error au chargement qui
empechait init() de tourner jusqu'au bout.

Correctif : tous les statements top-level executables ajoutes par la
feature production directe (addEventListener, wrappers
saveProduction/closeProductionModal) sont desormais entoures de
try/catch. Si l'un d'eux echoue, le warning est logge en console
mais init() continue normalement.

_esc devient une fonction independante (au lieu d'une const qui
dependait de escapeHtml a l'evaluation)."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
