#!/usr/bin/env bash
# Applique LUI-MÊME les 3 modifs pour la colonne FT (grid, header, cellule)
# puis commit + push. Idempotent : si tout est déjà appliqué, ne fait rien.
# Pas de dépendance à un état préalable du fichier — tout se fait dans le
# même run pour éviter qu'une auto-sync iCloud écrase entre les étapes.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des 3 patchs ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changed = 0

# Patch 1 : Grid normal (3 occurrences identiques)
old_grid_n = 'grid-template-columns: 72px 48px 32px 32px 52px minmax(140px, 2fr) minmax(100px, 1fr) 90px 40px 30px 100px 140px;'
new_grid_n = 'grid-template-columns: 72px 48px 32px 32px 52px minmax(140px, 2fr) 40px minmax(100px, 1fr) 90px 40px 30px 100px 140px;'
if old_grid_n in content:
    n = content.count(old_grid_n)
    content = content.replace(old_grid_n, new_grid_n)
    print(f"✓ Grid normal mis à jour ({n} occurrences)")
    changed += n
else:
    print("• Grid normal : déjà à jour ou structure différente")

# Patch 2 : Grid selection mode
old_grid_s = 'grid-template-columns: 32px 72px 48px 32px 32px 52px minmax(140px, 2fr) minmax(100px, 1fr) 90px 40px 30px 100px 140px;'
new_grid_s = 'grid-template-columns: 32px 72px 48px 32px 32px 52px minmax(140px, 2fr) 40px minmax(100px, 1fr) 90px 40px 30px 100px 140px;'
if old_grid_s in content:
    content = content.replace(old_grid_s, new_grid_s)
    print("✓ Grid sélection mis à jour")
    changed += 1
else:
    print("• Grid sélection : déjà à jour ou structure différente")

# Patch 3 : Header span FT
old_header = (
    '<span class="th-sort ${sa(\'tache\')}" onclick="toggleSort(\'tache\')">Tâche<span class="sort-arrow">${arrow(\'tache\')}</span></span>\n'
    '      <span class="th-sort ${sa(\'note\')}" onclick="toggleSort(\'note\')">Note<span class="sort-arrow">${arrow(\'note\')}</span></span>'
)
new_header = (
    '<span class="th-sort ${sa(\'tache\')}" onclick="toggleSort(\'tache\')">Tâche<span class="sort-arrow">${arrow(\'tache\')}</span></span>\n'
    '      <span class="th-center">FT</span>\n'
    '      <span class="th-sort ${sa(\'note\')}" onclick="toggleSort(\'note\')">Note<span class="sort-arrow">${arrow(\'note\')}</span></span>'
)
if old_header in content and 'class="th-center">FT<' not in content:
    content = content.replace(old_header, new_header)
    print("✓ Header FT inséré")
    changed += 1
elif 'class="th-center">FT<' in content:
    print("• Header FT : déjà présent")
else:
    print("⚠ Header : pattern Tâche+Note non trouvé. Ordre du tableau peut-être différent.")

# Patch 4 : Cellule bouton FT entre task-main et task-note-cell
old_cell = (
    '<div class="task-main">\n'
    '          <span class="task-name ${canEdit ? \'editable\' : \'\'}" title="${canEdit ? \'Cliquer pour modifier\' : esc(t.tache)}" ${canEdit ? `onclick="showEditTaskModal(\'${t.id}\')"` : \'\'}>${t.is_production ? \'🏭 \' : \'\'}${esc(t.tache)}</span>\n'
    '        </div>\n'
    '        <div class="task-note-cell">'
)
new_cell = (
    '<div class="task-main">\n'
    '          <span class="task-name ${canEdit ? \'editable\' : \'\'}" title="${canEdit ? \'Cliquer pour modifier\' : esc(t.tache)}" ${canEdit ? `onclick="showEditTaskModal(\'${t.id}\')"` : \'\'}>${t.is_production ? \'🏭 \' : \'\'}${esc(t.tache)}</span>\n'
    '        </div>\n'
    '        <div class="task-cell" style="text-align:center">${t.fiche_id ? `<button class="btn-action" style="background:#dbeafe;color:#1d4ed8" onclick="openFicheConsultModal(\'${t.fiche_id}\')" title="Afficher la fiche technique">📖</button>` : `<span style="color:var(--gray-300);font-size:0.72rem">—</span>`}</div>\n'
    '        <div class="task-note-cell">'
)
if old_cell in content and "openFicheConsultModal('${t.fiche_id}')" not in content:
    content = content.replace(old_cell, new_cell)
    print("✓ Cellule bouton FT insérée")
    changed += 1
elif "openFicheConsultModal('${t.fiche_id}')" in content:
    print("• Cellule FT : bouton déjà présent")
else:
    print("⚠ Cellule : pattern task-main → task-note-cell non trouvé.")

if changed > 0:
    p.write_text(content, encoding='utf-8')
    print(f"\n{changed} modifs écrites sur disque.")
else:
    print("\nAucun changement à appliquer (déjà à jour).")
PYEOF

echo
echo "=== git status après patchs ==="
git status --short

# Sortir proprement si rien à commiter
if git diff --quiet -- taf/index.html; then
  echo
  echo "Rien à commiter sur taf/index.html — le fichier était déjà à jour ou les patterns n'ont pas matché."
  exit 0
fi

echo
echo "=== Commit ==="
git add taf/index.html
git commit -m "feat(taf): restaure colonne FT (📖 fiche technique)

Réapplique en idempotent les 3 modifs de la colonne FT après que des
synchronisations iCloud successives les avaient effacées (récidive du
14/5 après écrasement par commit 562e3f1 Session inactivité, puis
re-écrasement entre Edit Cowork et commit).

Le script Python applique 4 patchs avec vérif d'idempotence :
- Grid normal (.task-row + .task-table-header) : 12 → 13 colonnes
- Grid sélection multiple : idem
- Header : span 'FT' inséré entre Tâche et Note
- Cellule : bouton 📖 (si t.fiche_id) ou '—' (sinon),
  onclick='openFicheConsultModal(\${t.fiche_id})' sans le 2e paramètre
  qui causait le bug d'échappement HTML précédemment"

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
