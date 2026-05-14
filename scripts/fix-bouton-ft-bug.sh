#!/usr/bin/env bash
# Fix bouton FT inerte (bug d'échappement onclick).
# Restaure aussi taf/index.html à la version GitHub (un cp iCloud→repo
# l'avait écrasé). Les 7 autres fichiers M sont stashés pour préservation.

set -euo pipefail
cd ~/planb-tools

echo "=== 1. Branche active ==="
BRANCH=$(git branch --show-current)
echo "$BRANCH"

echo
echo "=== 2. État actuel ==="
git status --short

echo
echo "=== 3. Stash des 7 fichiers modifiés (hors taf/) ==="
# On exclut taf/index.html du stash : sa version locale est obsolète.
# Les 7 autres sont peut-être des modifs de Claude Code à préserver.
to_stash=()
for f in admin/index.html checklist/index.html index.html production/index.html receptions/elis.html temperatures/index.html ventes/index.html; do
  if git diff --name-only HEAD | grep -qx "$f"; then
    to_stash+=("$f")
  fi
done

if [ ${#to_stash[@]} -gt 0 ]; then
  git stash push -m "pre-fix-bouton-ft-$(date +%Y%m%d-%H%M%S)" -- "${to_stash[@]}"
  echo "✓ ${#to_stash[@]} fichiers en stash"
else
  echo "(rien à stasher)"
fi

echo
echo "=== 4. Restauration de taf/index.html à la version HEAD ==="
git checkout HEAD -- taf/index.html

echo
echo "=== 5. Application du fix bouton FT ==="
python3 << 'PYEOF'
import sys
with open('taf/index.html', 'r', encoding='utf-8') as f:
    content = f.read()
old = """onclick="openFicheConsultModal('${t.fiche_id}', ${JSON.stringify(t.tache)})\""""
new = """onclick="openFicheConsultModal('${t.fiche_id}')\""""
if old not in content:
    print("⚠ Pattern non trouvé — peut-être déjà fixé ?")
    sys.exit(0)
content = content.replace(old, new)
with open('taf/index.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("✓ Fix appliqué")
PYEOF

echo
echo "=== 6. Commit + push ==="
git add taf/index.html
git commit -m "fix(taf): bouton FT inerte — bug d'échappement JSON.stringify

Le onclick du bouton 📖 dans la colonne FT contenait \${JSON.stringify(t.tache)}
qui produisait des guillemets doubles à l'intérieur d'un attribut onclick
lui-même entre guillemets doubles. Le HTML se cassait silencieusement et
le clic ne déclenchait rien.

Fix : suppression du paramètre tache_name (inutile — renderFiche()
utilise fiche.nom comme titre). Signature simplifiée.

Avant : onclick=\"openFicheConsultModal('xxx-uuid', \"Choucroute\")\"
Après : onclick=\"openFicheConsultModal('xxx-uuid')\""

git push origin "$BRANCH"

echo
echo "=== 7. Modifs en stash à ré-appliquer manuellement ==="
git stash list | head -3
echo
echo "Pour récupérer les modifs des 7 autres fichiers :"
echo "  git stash pop                  # essaie d'appliquer (peut conflicter)"
echo "  # ou pour voir d'abord :"
echo "  git stash show -p stash@{0} | head -50"

echo
echo "=== Terminé ✓ ==="
