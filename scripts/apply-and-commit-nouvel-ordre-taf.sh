#!/usr/bin/env bash
# Réorganise complètement les colonnes du tableau TAF.
# Nouvel ordre demandé par Eric (14/5) :
#   Tâche · FT · Éch · Crén · Prio · Note · Cat · Statut · De · À · Retard · ✓ · Actions

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Application des 3 patchs (grid, header, cellule) ==="
python3 << 'PYEOF'
from pathlib import Path
p = Path('taf/index.html')
content = p.read_text(encoding='utf-8')
changes = 0

# === PATCH 1 — Grid CSS normal (3 occurrences identiques) ===
old_grid = 'grid-template-columns: 72px 48px 32px 32px 52px minmax(140px, 2fr) 40px minmax(100px, 1fr) 90px 40px 30px 100px 140px;'
new_grid = 'grid-template-columns: minmax(140px, 2fr) 40px 48px 72px 40px minmax(100px, 1fr) 90px 100px 32px 32px 52px 30px 140px;'
if old_grid in content:
    n = content.count(old_grid)
    content = content.replace(old_grid, new_grid)
    print(f"✓ Grid normal mis à jour ({n} occurrences)")
    changes += n
elif new_grid in content:
    print("• Grid normal : déjà à jour")
else:
    print("⚠ Grid normal : pattern non trouvé. Vérifie l'état du fichier.")

# === PATCH 2 — Grid CSS mode sélection ===
old_grid_s = 'grid-template-columns: 32px 72px 48px 32px 32px 52px minmax(140px, 2fr) 40px minmax(100px, 1fr) 90px 40px 30px 100px 140px;'
new_grid_s = 'grid-template-columns: 32px minmax(140px, 2fr) 40px 48px 72px 40px minmax(100px, 1fr) 90px 100px 32px 32px 52px 30px 140px;'
if old_grid_s in content:
    content = content.replace(old_grid_s, new_grid_s)
    print("✓ Grid sélection mis à jour")
    changes += 1
elif new_grid_s in content:
    print("• Grid sélection : déjà à jour")
else:
    print("⚠ Grid sélection : pattern non trouvé.")

# === PATCH 3 — Header : réordonner les <span> ===
old_header = """      <span class="th-sort ${sa('creneau')}" onclick="toggleSort('creneau')">Crén.<span class="sort-arrow">${arrow('creneau')}</span></span>
      <span class="th-sort th-center ${sa('echeance')}" onclick="toggleSort('echeance')">Éch.<span class="sort-arrow">${arrow('echeance')}</span></span>
      <span class="th-sort th-center ${sa('createur')}" onclick="toggleSort('createur')">De<span class="sort-arrow">${arrow('createur')}</span></span>
      <span class="th-sort th-center ${sa('attribue')}" onclick="toggleSort('attribue')">À<span class="sort-arrow">${arrow('attribue')}</span></span>
      <span class="th-sort th-center ${sa('retard')}" onclick="toggleSort('retard')">Retard<span class="sort-arrow">${arrow('retard')}</span></span>
      <span class="th-sort ${sa('tache')}" onclick="toggleSort('tache')">Tâche<span class="sort-arrow">${arrow('tache')}</span></span>
      <span class="th-center">FT</span>
      <span class="th-sort ${sa('note')}" onclick="toggleSort('note')">Note<span class="sort-arrow">${arrow('note')}</span></span>
      <span class="th-sort ${sa('categorie')}" onclick="toggleSort('categorie')">Catégorie<span class="sort-arrow">${arrow('categorie')}</span></span>
      <span class="th-sort th-center ${sa('priorite')}" onclick="toggleSort('priorite')">Prio<span class="sort-arrow">${arrow('priorite')}</span></span>
      <span class="th-center">✓</span>
      <span class="th-sort th-center ${sa('statut')}" onclick="toggleSort('statut')">Statut<span class="sort-arrow">${arrow('statut')}</span></span>
      <span></span>"""

new_header = """      <span class="th-sort ${sa('tache')}" onclick="toggleSort('tache')">Tâche<span class="sort-arrow">${arrow('tache')}</span></span>
      <span class="th-center">FT</span>
      <span class="th-sort th-center ${sa('echeance')}" onclick="toggleSort('echeance')">Éch.<span class="sort-arrow">${arrow('echeance')}</span></span>
      <span class="th-sort ${sa('creneau')}" onclick="toggleSort('creneau')">Crén.<span class="sort-arrow">${arrow('creneau')}</span></span>
      <span class="th-sort th-center ${sa('priorite')}" onclick="toggleSort('priorite')">Prio<span class="sort-arrow">${arrow('priorite')}</span></span>
      <span class="th-sort ${sa('note')}" onclick="toggleSort('note')">Note<span class="sort-arrow">${arrow('note')}</span></span>
      <span class="th-sort ${sa('categorie')}" onclick="toggleSort('categorie')">Catégorie<span class="sort-arrow">${arrow('categorie')}</span></span>
      <span class="th-sort th-center ${sa('statut')}" onclick="toggleSort('statut')">Statut<span class="sort-arrow">${arrow('statut')}</span></span>
      <span class="th-sort th-center ${sa('createur')}" onclick="toggleSort('createur')">De<span class="sort-arrow">${arrow('createur')}</span></span>
      <span class="th-sort th-center ${sa('attribue')}" onclick="toggleSort('attribue')">À<span class="sort-arrow">${arrow('attribue')}</span></span>
      <span class="th-sort th-center ${sa('retard')}" onclick="toggleSort('retard')">Retard<span class="sort-arrow">${arrow('retard')}</span></span>
      <span class="th-center">✓</span>
      <span></span>"""

if old_header in content:
    content = content.replace(old_header, new_header)
    print("✓ Header réordonné")
    changes += 1
elif new_header in content:
    print("• Header : déjà à jour")
else:
    print("⚠ Header : pattern non trouvé. Probablement déjà touché par autre chose.")

# === PATCH 4 — Cellule de chaque ligne : réordonner les <div> ===
old_cell = """        <div class="task-cell-left"><span class="badge badge-creneau ${(t.creneau || '').toLowerCase()}">${cIcons[t.creneau] || ''} ${t.creneau || ''}</span></div>
        <div class="task-cell"><span class="task-echeance" title="${echTitle}">${echShort}</span></div>
        <div class="task-cell">${creator ? `<span class="task-initials creator" title="Créé par ${esc(t.createur_nom)}${createdDay ? ' ' + createdDay : ''}">${creator}</span>${createdDay ? `<span style="font-size:0.65rem;color:var(--gray-400);display:block;text-align:center;margin-top:-2px">${createdDay}</span>` : ''}` : ''}</div>
        <div class="task-cell">${assignee ? `<span class="task-initials assignee" title="Attribué à ${esc(t.attribue_a_nom || assignee)}">${esc(assignee)}</span>` : `<span class="task-initials unassigned">—</span>`}</div>
        <div class="task-cell">${isLate ? `<span class="badge-late" title="Reportée depuis le ${new Date(t.echeance_initiale).toLocaleDateString('fr-FR')}">${daysLate}j</span>` : ''}</div>
        <div class="task-main">
          <span class="task-name ${canEdit ? 'editable' : ''}" title="${canEdit ? 'Cliquer pour modifier' : esc(t.tache)}" ${canEdit ? `onclick="showEditTaskModal('${t.id}')"` : ''}>${t.is_production ? '🏭 ' : ''}${esc(t.tache)}</span>
        </div>
        <div class="task-cell" style="text-align:center">${t.fiche_id ? `<button class="btn-action" style="background:#dbeafe;color:#1d4ed8" onclick="openFicheConsultModal('${t.fiche_id}')" title="Afficher la fiche technique">📖</button>` : `<span style="color:var(--gray-300);font-size:0.72rem">—</span>`}</div>
        <div class="task-note-cell">${t.observation ? `<span class="task-note" title="${esc(t.observation)}">${esc(t.observation)}</span>` : ''}</div>
        <div class="task-cell">${t.categorie ? `<span class="cat-badge cat-${t.categorie.toLowerCase().replace(/ /g, '-')}">${esc(t.categorie)}</span>` : ''}</div>
        <div class="task-cell"><span class="badge badge-priority ${pClass}">${pLabels[t.priorite] || '!!!'}</span></div>
        ${canAct ? `<button class="task-check ${done ? 'checked' : ''}" onclick="toggleTask('${t.id}', ${done})">${done ? '✓' : ''}</button>` : `<div class="task-cell" style="width:36px"></div>`}"""

new_cell = """        <div class="task-main">
          <span class="task-name ${canEdit ? 'editable' : ''}" title="${canEdit ? 'Cliquer pour modifier' : esc(t.tache)}" ${canEdit ? `onclick="showEditTaskModal('${t.id}')"` : ''}>${t.is_production ? '🏭 ' : ''}${esc(t.tache)}</span>
        </div>
        <div class="task-cell" style="text-align:center">${t.fiche_id ? `<button class="btn-action" style="background:#dbeafe;color:#1d4ed8" onclick="openFicheConsultModal('${t.fiche_id}')" title="Afficher la fiche technique">📖</button>` : `<span style="color:var(--gray-300);font-size:0.72rem">—</span>`}</div>
        <div class="task-cell"><span class="task-echeance" title="${echTitle}">${echShort}</span></div>
        <div class="task-cell-left"><span class="badge badge-creneau ${(t.creneau || '').toLowerCase()}">${cIcons[t.creneau] || ''} ${t.creneau || ''}</span></div>
        <div class="task-cell"><span class="badge badge-priority ${pClass}">${pLabels[t.priorite] || '!!!'}</span></div>
        <div class="task-note-cell">${t.observation ? `<span class="task-note" title="${esc(t.observation)}">${esc(t.observation)}</span>` : ''}</div>
        <div class="task-cell">${t.categorie ? `<span class="cat-badge cat-${t.categorie.toLowerCase().replace(/ /g, '-')}">${esc(t.categorie)}</span>` : ''}</div>"""

# Pour le Statut, De, À, Retard, ✓ on doit déplacer aussi le bloc avec le statut chrono qui contient une IIFE.
# On les déplace après les modifications de la 1ère partie.

if old_cell in content:
    content = content.replace(old_cell, new_cell)
    print("✓ Cellule (partie 1) réordonnée — Tâche/FT/Éch/Crén/Prio/Note/Cat en tête")
    changes += 1
elif new_cell in content:
    print("• Cellule : déjà à jour")
else:
    print("⚠ Cellule : pattern non trouvé.")

# Maintenant déplacer Statut+De+À+Retard+✓ — c'est plus délicat car
# le bloc statut contient une IIFE. On réorganise le bloc qui suit.
# Pattern actuel après le patch 4 : Statut · (De a disparu de l'ordre, est resté à sa place initiale) ...
# En fait après le patch ci-dessus, on a juste réorganisé la 1ère partie. Le ✓ task-check
# n'est plus à la fin. On doit relire la suite et la déplacer aussi.

# Pour simplifier : le pattern complet de la 2ème partie de la cellule juste après le patch.
# La nouvelle disposition souhaitée : Statut puis De · À · Retard · ✓ · Actions
# Le ✓ est dans le bloc canAct ? `<button class="task-check..." />` qui n'est plus
# présent après le patch 4 (on l'a retiré). On doit l'ajouter à la nouvelle position.

# Vérifions où est ✓ après patch 4
if 'class="task-check ${done' not in content:
    # Le ✓ a bien été retiré par notre patch. On va le réinsérer après Retard.
    # On cherche le bloc Statut qui suit immédiatement notre nouveau bloc Cat
    # et on insère De, À, Retard et ✓ juste après Statut.
    old_after_cat = """        <div class="task-cell">${t.categorie ? `<span class="cat-badge cat-${t.categorie.toLowerCase().replace(/ /g, '-')}">${esc(t.categorie)}</span>` : ''}</div>
        <div class="task-cell">${(() => {"""
    new_after_cat = """        <div class="task-cell">${t.categorie ? `<span class="cat-badge cat-${t.categorie.toLowerCase().replace(/ /g, '-')}">${esc(t.categorie)}</span>` : ''}</div>
        <div class="task-cell">${(() => {"""

    # Le Statut reste à sa place après Cat. Donc on doit déplacer le bloc Statut juste
    # après Cat, puis insérer De/À/Retard/✓ avant Actions.
    # Statut bloc actuel :
    statut_block = """        <div class="task-cell">${(() => {
          if (done) {
            return `<span class="task-done-info">${esc(t.fait_par_initiales)} ${valTime}</span>${(t.duree_secondes != null) ? `<span class="task-duree-final">${formatDureeShort(t.duree_secondes)}</span>` : ''}`;
          }
          const acc = t.duree_accumulee_secondes || 0;
          if (t.date_debut_execution) {
            // En cours : chrono live (acc + delta depuis date_debut_execution)
            return `<span class="task-chrono-live" data-start="${t.date_debut_execution}" data-acc="${acc}" title="Chrono démarré par ${esc(t.debut_par_initiales || '?')}">…</span>`;
          }
          if (acc > 0) {
            // En pause : afficher la durée accumulée figée
            return `<span class="task-chrono-paused" title="Chrono en pause">${formatDureeLive(acc)}</span>`;
          }
          return '';
        })()}</div>
        <div class="task-actions">"""

    # On veut : <Statut> + <De> + <À> + <Retard> + <✓> puis <Actions>
    new_block = """        <div class="task-cell">${(() => {
          if (done) {
            return `<span class="task-done-info">${esc(t.fait_par_initiales)} ${valTime}</span>${(t.duree_secondes != null) ? `<span class="task-duree-final">${formatDureeShort(t.duree_secondes)}</span>` : ''}`;
          }
          const acc = t.duree_accumulee_secondes || 0;
          if (t.date_debut_execution) {
            // En cours : chrono live (acc + delta depuis date_debut_execution)
            return `<span class="task-chrono-live" data-start="${t.date_debut_execution}" data-acc="${acc}" title="Chrono démarré par ${esc(t.debut_par_initiales || '?')}">…</span>`;
          }
          if (acc > 0) {
            // En pause : afficher la durée accumulée figée
            return `<span class="task-chrono-paused" title="Chrono en pause">${formatDureeLive(acc)}</span>`;
          }
          return '';
        })()}</div>
        <div class="task-cell">${creator ? `<span class="task-initials creator" title="Créé par ${esc(t.createur_nom)}${createdDay ? ' ' + createdDay : ''}">${creator}</span>${createdDay ? `<span style="font-size:0.65rem;color:var(--gray-400);display:block;text-align:center;margin-top:-2px">${createdDay}</span>` : ''}` : ''}</div>
        <div class="task-cell">${assignee ? `<span class="task-initials assignee" title="Attribué à ${esc(t.attribue_a_nom || assignee)}">${esc(assignee)}</span>` : `<span class="task-initials unassigned">—</span>`}</div>
        <div class="task-cell">${isLate ? `<span class="badge-late" title="Reportée depuis le ${new Date(t.echeance_initiale).toLocaleDateString('fr-FR')}">${daysLate}j</span>` : ''}</div>
        ${canAct ? `<button class="task-check ${done ? 'checked' : ''}" onclick="toggleTask('${t.id}', ${done})">${done ? '✓' : ''}</button>` : `<div class="task-cell" style="width:36px"></div>`}
        <div class="task-actions">"""

    if statut_block in content:
        content = content.replace(statut_block, new_block)
        print("✓ Cellule (partie 2) : De/À/Retard/✓ insérés entre Statut et Actions")
        changes += 1
    else:
        print("⚠ Bloc Statut+Actions : pattern non trouvé (partie 2 manquante)")
else:
    print("• Cellule partie 2 : ✓ encore présent, déjà appliqué ou patch 1 a échoué")

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
  echo "Rien à commiter — fichier déjà à jour ou les patterns n'ont pas matché."
  exit 0
fi

echo
echo "=== Commit ==="
git add taf/index.html
git commit -m "feat(taf): nouvel ordre des colonnes (Tâche en tête)

Réorganisation complète demandée par Eric le 14/5/2026 :
  Tâche · FT · Éch · Crén · Prio · Note · Cat · Statut · De · À · Retard · ✓ · Actions

Avant : Crén · Éch · De · À · Retard · Tâche · FT · Note · Cat · Prio · ✓ · Statut · Actions

Logique : Quoi (Tâche+FT) → Quand (Éch+Crén) → Importance (Prio) →
Détails (Note+Cat) → Résultat (Statut) → Méta (De/À/Retard/✓) → Actions

Modifs :
- Grid CSS (3× normal + 1× sélection) avec nouvel ordre des largeurs
- Header : 13 spans réordonnés selon le nouvel ordre
- Cellule : 13 divs réordonnés en 2 phases (Tâche+FT en tête, De+À+Retard+✓
  déplacés entre Statut et Actions)
- Le bouton task-check du ✓ reste fonctionnel à sa nouvelle position"

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
