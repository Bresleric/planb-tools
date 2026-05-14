#!/usr/bin/env bash
# Tableau TAF — nouvel ordre des colonnes + ajout colonne Fiche Technique
# Crén · Éch · De · À · Retard · Tâche · FT · Note · Catégorie · Prio · ✓ · Statut · Actions

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html
git commit -m "feat(taf): colonne Fiche Technique + réordre des colonnes

Tableau TAF — nouvel ordre des colonnes :
  Crén · Éch · De · À · Retard · Tâche · FT · Note · Catégorie · Prio · ✓ · Statut · Actions

Avant le réordre : ... · Retard · Catégorie · Note · Tâche · Prio · ...
Après le réordre : ... · Retard · Tâche · FT · Note · Catégorie · Prio · ...

Nouvelle colonne 'FT' (40px) entre Tâche et Note :
- Si t.fiche_id existe : bouton 📖 bleu (btn-action) qui ouvre
  openFicheConsultModal(fiche_id, tache_name) — modale plein écran
  avec ingrédients, instructions, temps, etc. (déjà existante).
- Si pas de fiche : '—' grisé.

Modifs CSS :
- 3 occurrences de grid-template-columns mises à jour
  (.task-row, .task-table-header, mode sélection)
- Largeur insérée : 40px pour la cellule du bouton FT

Smoke tests 8/8, braces/parens équilibrés."

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
