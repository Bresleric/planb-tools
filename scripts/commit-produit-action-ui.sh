#!/usr/bin/env bash
# UI Admin : ajout colonnes + champs produit/action dans le tableau et la modale.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html Mapping_Produit_Action.xlsx
git commit -m "feat(taf/admin): colonnes + champs produit/action

Tableau Admin (predefined_tasks) — ajout 2 colonnes :
- Produit (vert teal) : composante 'matière' de la tâche (ex: oignons, onglet)
- Action (marron) : composante 'verbe' (ex: Couper, Cuire, Préparer)
Tri sur les 2 colonnes, recherche élargie aux champs produit/action.

Modale d'édition — 2 champs côte-à-côte juste après le Nom :
- Input texte 🥕 Produit (libre)
- Input texte 🛠 Action (avec datalist d'actions courantes en suggestion)
Les valeurs sont sauvegardées dans predefined_tasks.produit/action
(colonnes ajoutées le 4/5/2026 via production/schema-produit-action.sql,
non utilisées jusqu'à présent).

Versionne aussi Mapping_Produit_Action.xlsx (proposition de
décomposition automatique des 137 noms existants, à valider par Eric
avant migration en BDD)."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
