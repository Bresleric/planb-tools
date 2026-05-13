#!/usr/bin/env bash
# Masque l'onglet "+ Créer" + ajoute une ligne "+ Ajouter une tâche"
# en fin de liste des tâches qui rouvre l'écran Créer existant.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "feat(taf): masque onglet 'Créer' + ligne '+ Ajouter une tâche' en fin de liste

- Onglet '+ Créer' dans la barre des tabs : style='display:none'.
  La fonction switchTab('creer') reste accessible (déclenchée par les
  nouveaux boutons + Ajouter et par le code existant).
- Ligne pleine largeur '+ Ajouter une tâche' (fond #fff7ed, bordure
  pointillée orange, pastille ronde avec '+') ajoutée :
  • à la fin de la liste des tâches du jour,
  • et dans l'état vide ('Aucune tâche').
  Tap sur la ligne = bascule vers l'écran Créer existant (inchangé).

Permet d'avoir une UX plus fluide sur mobile : moins d'onglets dans la
barre, action de création toujours visible en fin de scroll.

Smoke tests 6/6 ✓, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
