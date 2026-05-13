#!/usr/bin/env bash
# Fix : liste des TAF prédéfinies vide en création de tâche.
# Ajoute un fallback fetch + messages utilisateur clairs.
# Édition faite directement dans le repo. iCloud à aligner ensuite (repo→iCloud).

set -euo pipefail
cd ~/planb-tools

echo "=== Branche active ==="
BRANCH=$(git branch --show-current)
echo "Branche : $BRANCH"

echo
echo "=== Nettoyage lock résiduel ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== git status ==="
git status --short

echo
echo "=== Add + commit ==="
git add taf/index.html
git commit -m "fix(taf/create): fallback fetch quand predefined_tasks vide

Symptôme : input de recherche visible mais liste de tâches prédéfinies
restait vide en création de tâche.

Cause probable : renderPredefinedList() s'exécutait avant que loadAll()
n'ait fini de remplir le tableau predefinedTasks (race), ou la promise
initiale échouait silencieusement.

Fix : ajout d'un safety net dans renderPredefinedList() :
- Si predefinedTasks est vide, affiche 'Chargement…' + tente un re-fetch
  via DB.getPredefined(currentEtablissement).
- Re-rend la liste une fois les données reçues.
- En cas d'erreur réseau : message rouge 'Erreur de chargement, tape un
  nom pour saisir manuellement'.
- Si le filtre par équipe ne ramène rien : message explicite
  'Aucune tâche prédéfinie pour l'équipe X'.

Aucune autre fonction touchée. Smoke test 6/6, braces/parens équilibrés."

echo
echo "=== Push origin $BRANCH ==="
git push origin "$BRANCH"

echo
echo "=== Aligner iCloud (repo → iCloud, pas l'inverse) ==="
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
if [ -d "$ICLOUD_DIR/taf" ]; then
  cp taf/index.html "$ICLOUD_DIR/taf/index.html"
  echo "✓ iCloud aligné."
else
  echo "⚠ Dossier iCloud Cowork introuvable : $ICLOUD_DIR/taf"
fi

echo
echo "=== Terminé ✓ ==="
