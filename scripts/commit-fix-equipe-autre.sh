#!/usr/bin/env bash
# Fix : équipe "Autre" = super-rôle (admin) → voit toutes les tâches prédéfinies.
# + autocomplete navigateur désactivé sur l'input search-predef
# + message "Aucun résultat" affiché même quand l'utilisateur tape.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "fix(taf/create): équipe Autre voit toutes les tâches + autocomplete off

Symptôme : avec équipe 'Autre' sélectionnée (cas par défaut pour un admin),
le filtre par équipe rejetait toutes les predefined_tasks (aucune n'a
equipe='autre' en base). L'utilisateur ne voyait que '+ Créer «…»'.

Fix renderPredefinedList :
- 'autre' devient un super-rôle qui voit TOUTES les tâches prédéfinies
  (cuisine, salle, plonge, ou sans équipe). Les rôles cuisine/plonge
  partagent toujours leur base, salle reste isolée.
- Le message 'Aucun résultat / Aucune tâche prédéfinie pour l'équipe X'
  s'affiche désormais aussi quand l'utilisateur a tapé du texte
  (avant : seulement si l'input était vide).
- + l'option '+ Créer «…»' reste visible en parallèle.

Fix HTML input search-predef :
- autocomplete='off' autocorrect='off' autocapitalize='off' spellcheck='false'
  pour empêcher les suggestions natives du navigateur (chip 'choucroute ✕'
  qui apparaissait sur la capture d'Eric)."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
