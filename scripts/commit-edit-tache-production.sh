#!/usr/bin/env bash
# Ajout du rattachement production dans la modale d'édition TAF.
# Permet à un manager+ de transformer une tâche existante en tâche de production
# et de lui rattacher une fiche technique.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "feat(taf/edit): rattachement production + fiche technique

Permet à un manager+ de modifier une TAF existante pour la lier au
workflow production. Utile pour les tâches du jour créées avant la
liaison BDD complète, ou créées custom (sans predefined_task source).

Modale showEditTaskModal — nouveaux champs :
- Checkbox '🏭 Tâche de production (lier à une fiche technique)'
- Si cochée :
  • Chips 'Type de production' (mise_en_place / produit_intermediaire / produit_fini)
  • Recherche fiche technique avec dropdown auto-complete (8 résultats max)
  • Affichage de la fiche choisie (badge code + nom + bouton ✕ pour retirer)
- Pré-remplit la catégorie production depuis la fiche choisie si vide
- Décocher la case ne perd pas l'état (l'utilisateur peut réactiver)

submitEditTask — sauvegarde les 3 champs :
- is_production (bool)
- fiche_id (uuid ou null si décoché)
- categorie_production (enum ou null si décoché)

Smoke tests 13/13 ✓, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
