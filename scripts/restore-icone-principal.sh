#!/bin/bash
# ============================================================
# Restauration du toggle 🎯 Principal sur les ingredients d'une
# fiche technique (regression du commit ec9a6cf "ajout categorie
# 'Plat'" qui avait supprime par erreur les 3 emplacements) :
#   - CSS .ing-principal-wrap / .ing-principal-icon
#   - HTML <label> + <input type=checkbox> dans addIngredientRow
#   - Lecture du checkbox + push est_principal dans saveFiche
#   - Persistance est_principal dans DB.saveIngredients
#
# Sans ce toggle, l'admin ne peut plus marquer un ingredient
# comme principal, et donc le scan obligatoire (B-2) ne se
# declenche jamais pour cette fiche.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
echo ""

git add production/index.html scripts/restore-icone-principal.sh

echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/restore-icone-principal.sh
echo ""

git commit -m "fix(production): restaurer le toggle 🎯 Principal sur ingredients

Regression du commit ec9a6cf (ajout categorie 'Plat') qui avait
supprime par erreur :
- le CSS .ing-principal-wrap / .ing-principal-icon
- le <label><input type=checkbox> dans addIngredientRow
- la lecture du checkbox dans saveFiche
- la persistance est_principal dans DB.saveIngredients

Sans ce toggle, le scan obligatoire B-2 ne pouvait plus etre
declenche pour les nouvelles fiches (ingredients principaux non
marquables)."

echo ""
echo "=== Push ==="
git push

echo "=== Termine OK ==="
