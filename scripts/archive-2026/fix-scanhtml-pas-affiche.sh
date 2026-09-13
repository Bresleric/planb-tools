#!/usr/bin/env bash
# Bugfix : la variable scanHTML était construite mais jamais incluse
# dans le innerHTML final de renderFiche. Conséquence : le bloc orange
# '🎯 Ingrédients à scanner' avec les boutons '📷 Scanner' n'apparaît
# pas dans la modale fiche au démarrage du TAF.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application du fix ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')

old = "document.getElementById('fiche-body').innerHTML = metaHTML + ingHTML + instrHTML + notesHTML;"
new = "document.getElementById('fiche-body').innerHTML = metaHTML + scanHTML + ingHTML + instrHTML + notesHTML;"

if old in content:
    content = content.replace(old, new)
    p.write_text(content, encoding='utf-8')
    print("✓ scanHTML injecté dans renderFiche.innerHTML")
elif new in content:
    print("• déjà à jour")
else:
    print("⚠ pattern innerHTML metaHTML non trouvé")
PYEOF

echo
git status --short

if git diff --quiet -- taf/index.html; then
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html
git commit -m "fix(scan-fefo phase 3): scanHTML jamais affiché dans renderFiche

La variable scanHTML (bloc orange '🎯 Ingrédients à scanner' avec les
boutons '📷 Scanner' violets) était bien construite par la condition
\`if (principaux.length > 0)\`, mais jamais incluse dans le innerHTML
final de la modale.

Avant : innerHTML = metaHTML + ingHTML + instrHTML + notesHTML
Après : innerHTML = metaHTML + scanHTML + ingHTML + instrHTML + notesHTML

Résultat visible : le compteur '5, dont 1 principal' et l'icône 🎯
inline sur les lignes du tableau d'ingrédients fonctionnaient déjà
(ils sont dans ingHTML). Mais le bloc orange en tête, avec les boutons
violets, n'apparaissait pas du tout. Ce fix le rend visible."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo
echo "=== Terminé ✓ ==="
