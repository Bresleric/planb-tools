#!/usr/bin/env bash
# Déplace la colonne ✓ tout à droite (après Actions) + ajoute une
# modale de confirmation au clic pour valider/réouvrir une tâche.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="
rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des patchs ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# ============================================================
# 1. Grid CSS — déplacer la 12ème colonne (✓ 30px) après la 13ème (Actions 140px)
# ============================================================
old_grid_n = 'grid-template-columns: minmax(140px, 2fr) 40px 48px 72px 40px minmax(100px, 1fr) 90px 100px 32px 32px 52px 30px 140px;'
new_grid_n = 'grid-template-columns: minmax(140px, 2fr) 40px 48px 72px 40px minmax(100px, 1fr) 90px 100px 32px 32px 52px 140px 30px;'
if old_grid_n in content:
    n = content.count(old_grid_n)
    content = content.replace(old_grid_n, new_grid_n)
    print(f"✓ Grid normal mis à jour ({n} occurrences)")
    changes += n
elif new_grid_n in content:
    print("• Grid normal : déjà à jour")
else:
    print("⚠ Grid normal : pattern non trouvé")

old_grid_s = 'grid-template-columns: 32px minmax(140px, 2fr) 40px 48px 72px 40px minmax(100px, 1fr) 90px 100px 32px 32px 52px 30px 140px;'
new_grid_s = 'grid-template-columns: 32px minmax(140px, 2fr) 40px 48px 72px 40px minmax(100px, 1fr) 90px 100px 32px 32px 52px 140px 30px;'
if old_grid_s in content:
    content = content.replace(old_grid_s, new_grid_s)
    print("✓ Grid sélection mis à jour")
    changes += 1
elif new_grid_s in content:
    print("• Grid sélection : déjà à jour")
else:
    print("⚠ Grid sélection : pattern non trouvé")

# ============================================================
# 2. Header — déplacer <span class="th-center">✓</span> après le <span></span> final
# ============================================================
old_header = """      <span class="th-sort th-center ${sa('retard')}" onclick="toggleSort('retard')">Retard<span class="sort-arrow">${arrow('retard')}</span></span>
      <span class="th-center">✓</span>
      <span></span>"""
new_header = """      <span class="th-sort th-center ${sa('retard')}" onclick="toggleSort('retard')">Retard<span class="sort-arrow">${arrow('retard')}</span></span>
      <span></span>
      <span class="th-center">✓</span>"""
if old_header in content:
    content = content.replace(old_header, new_header)
    print("✓ Header : ✓ déplacé en fin")
    changes += 1
elif new_header in content:
    print("• Header : déjà à jour")
else:
    print("⚠ Header : pattern Retard+✓+vide non trouvé")

# ============================================================
# 3. Cellule — déplacer task-check après task-actions
# ============================================================
old_cell = """        ${canAct ? `<button class="task-check ${done ? 'checked' : ''}" onclick="toggleTask('${t.id}', ${done})">${done ? '✓' : ''}</button>` : `<div class="task-cell" style="width:36px"></div>`}
        <div class="task-actions">"""

# La task-actions ouvre un div ; il faut trouver sa fermeture pour intercaler le ✓ après
# On va plutôt faire l'opération en 2 sous-patchs : (a) retirer le task-check de sa position actuelle,
# (b) l'insérer juste après le </div> de task-actions.

# Sous-patch 3a : retirer task-check de l'endroit actuel (juste avant task-actions ouvrant)
remove_old = """        ${canAct ? `<button class="task-check ${done ? 'checked' : ''}" onclick="toggleTask('${t.id}', ${done})">${done ? '✓' : ''}</button>` : `<div class="task-cell" style="width:36px"></div>`}
        <div class="task-actions">"""
keep_new_position = """        <div class="task-actions">"""

# Sous-patch 3b : trouver la fermeture de task-actions et y ajouter le task-check après
# La fermeture de task-actions ressemble à : </div>\n      </div>` (tab+`)
# On cherche : `</div>\n      </div>`;` (la fin de task-row)
old_close = """        </div>
      </div>`;
    }).join('');"""
new_close = """        </div>
        ${canAct ? `<button class="task-check ${done ? 'checked' : ''}" onclick="confirmToggleTask('${t.id}', ${done})">${done ? '✓' : ''}</button>` : `<div class="task-cell" style="width:36px"></div>`}
      </div>`;
    }).join('');"""

if (remove_old in content) and (old_close in content) and ("confirmToggleTask" not in content):
    content = content.replace(remove_old, keep_new_position)
    content = content.replace(old_close, new_close)
    print("✓ Cellule : task-check déplacée après task-actions + onclick → confirmToggleTask")
    changes += 1
elif "confirmToggleTask" in content:
    print("• Cellule : déjà à jour (confirmToggleTask présent)")
else:
    print("⚠ Cellule : patterns non trouvés (peut-être déjà modifié différemment)")

# ============================================================
# 4. Ajouter la fonction confirmToggleTask juste avant toggleTask
# ============================================================
if "async function confirmToggleTask" in content:
    print("• confirmToggleTask : déjà définie")
else:
    insert_marker = "  async function toggleTask(id, isDone) {"
    new_function = """  // Confirmation avant toggle (sauf production : la modale de saisie sert déjà de confirmation)
  function confirmToggleTask(id, isDone) {
    const task = tasks.find(t => t.id === id);
    if (!task) return;
    // Production en attente : passer directement (modale de saisie va s'ouvrir)
    if (!isDone && task.is_production) {
      return toggleTask(id, isDone);
    }
    const titre = isDone ? 'Réouvrir la tâche ?' : 'Valider la tâche ?';
    const message = isDone
      ? `<p style="font-size:0.9rem">Cette tâche est marquée comme terminée. La réouvrir va effacer la validation, la durée et le chrono.</p><p style="font-size:0.85rem;margin-top:8px"><strong>${esc(task.tache)}</strong></p>`
      : `<p style="font-size:0.9rem">Confirmer que cette tâche est terminée ?</p><p style="font-size:0.85rem;margin-top:8px"><strong>${esc(task.tache)}</strong></p>`;
    const action = isDone ? 'Réouvrir' : 'Valider';
    const cls = isDone ? 'danger' : 'primary';
    openModal(titre, message, [
      { label: 'Annuler', action: 'closeModal()', cls: '' },
      { label: action, action: `closeModal(); toggleTask('${id}', ${isDone})`, cls: cls }
    ]);
  }

"""
    if insert_marker in content:
        content = content.replace(insert_marker, new_function + insert_marker)
        print("✓ confirmToggleTask insérée")
        changes += 1
    else:
        print("⚠ confirmToggleTask : marker toggleTask non trouvé")

# Sauvegarde
if changes > 0:
    p.write_text(content, encoding='utf-8')
    print(f"\n✅ {changes} modifs écrites sur disque.")
else:
    print("\nAucun changement appliqué.")
PYEOF

echo
echo "=== git status ==="
git status --short

if git diff --quiet -- taf/index.html; then
  echo
  echo "Rien à commiter."
  exit 0
fi

echo
echo "=== Commit + push ==="
git add taf/index.html
git commit -m "feat(taf): ✓ tout à droite + confirmation au clic

Tableau TAF — nouvel ordre des colonnes :
  Tâche · FT · Éch · Crén · Prio · Note · Cat · Statut · De · À · Retard · Actions · ✓
(la colonne de validation ✓ passe tout à la fin, après les actions)

Confirmation au clic :
- confirmToggleTask() intercepte le clic et ouvre une modale openModal
  avec un bouton 'Annuler' + un bouton 'Valider' (ou 'Réouvrir' si la
  tâche était déjà faite, en rouge danger).
- Pour les tâches de production (is_production=true) en attente de
  validation : pas de modale supplémentaire, on enchaîne directement
  sur openProductionModal qui sert déjà de confirmation.
- Affiche le libellé de la tâche dans le message pour éviter les
  validations par erreur.

Modifs :
- Grid CSS (normal + sélection) : 30px déplacé après 140px en position finale
- Header : <span>✓</span> déplacé après <span></span> Actions
- Cellule : task-check déplacée après task-actions, onclick →
  confirmToggleTask au lieu de toggleTask"

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
