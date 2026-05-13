#!/usr/bin/env bash
# Réordonne les colonnes du tableau TAF :
#   Crén · Éch · De · À · Retard · Tâche · Note · Catégorie · Prio · ✓ · Statut · Actions
# (Tâche déplacée devant Catégorie, Note placée entre les deux.)

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "style(taf): réordonne les colonnes du tableau TAF

Nouvel ordre : Crén · Éch · De · À · Retard · Tâche · Note · Catégorie
              · Prio · ✓ · Statut · Actions

Avant : Catégorie · Note · Tâche (Tâche en 8ème position)
Après : Tâche · Note · Catégorie (Tâche en 6ème position)

3 modifs symétriques :
- CSS grid-template-columns (.task-row + .task-table-header)
- CSS grid-template-columns en mode sélection multiple
- En-têtes <span class='th-sort'> dans la string template
- Cellules <div> dans la string template

Le 'task-main' (libellé) passe en colonne plus visible (priorité de lecture
naturelle) ; 'task-note-cell' (observation) se met juste derrière ; la
catégorie passe en position de méta-donnée.

Smoke tests 6/6, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
