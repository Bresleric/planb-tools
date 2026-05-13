#!/usr/bin/env bash
# Refonte création de tâche : source = fiches techniques + chemin "À créer"
# Vue Admin : bloc "Tâches à traiter" avec actions Lier/Promouvoir/Ignorer

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add taf/index.html scripts/migrations/2026-05-09_tasks_a_traiter.sql
git commit -m "feat(taf): création basée sur fiches + workflow 'À créer' → Admin

CRÉATION DE TÂCHE — refonte de la liste source :
- Avant : autocompletion sur predefined_tasks (118 entrées, beaucoup de doublons)
- Après : autocompletion sur fiches_techniques (catalogue Production)
  + bouton 'À créer' toujours visible en bas (si pas de fiche trouvée)

Quand fiche sélectionnée :
- selectedPredefined = { source_type: 'fiche', fiche_id, nom, is_production: true }
- catégorie TAF pré-sélectionnée sur 'Production'

Quand 'À créer' choisi :
- selectedPredefined = { source_type: 'a_creer', nom: <saisi>, is_a_creer: true }
- À la création, tasks.a_traiter = true (la tâche apparaît dans la
  vue Admin pour décision)

NOUVELLE COLONNE tasks.a_traiter (migration SQL séparée à appliquer):
- scripts/migrations/2026-05-09_tasks_a_traiter.sql
- BOOLEAN NOT NULL DEFAULT false
- Index partiel WHERE a_traiter = true

VUE ADMIN — bloc 'Tâches à traiter' en haut de l'onglet :
- Liste les tasks WHERE a_traiter = true AND fait_par_id IS NULL
- Stat-card jaune dans le bandeau des chiffres
- 3 actions par ligne :
  • 🔗 Lier fiche : modale avec dropdown des fiches → met is_production
    + fiche_id + categorie_production, retire a_traiter
  • + Predef : crée une predefined_task à partir du libellé, retire a_traiter
  • Ignorer : retire juste a_traiter (la tâche reste fonctionnelle)

Smoke tests 12/12, braces/parens équilibrés.

⚠ APPLICATION DE LA MIGRATION SQL OBLIGATOIRE avant que le code marche :
   ouvrir Supabase Studio → SQL Editor → coller le contenu de
   scripts/migrations/2026-05-09_tasks_a_traiter.sql → Run"

git push origin "$BRANCH"

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Cowork/PlanB Tools"
[ -d "$ICLOUD_DIR/taf" ] && cp taf/index.html "$ICLOUD_DIR/taf/index.html" && echo "✓ iCloud aligné" \
  || echo "(iCloud non trouvé, ignoré)"

echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer la migration SQL :"
echo "  Supabase Studio → SQL Editor → coller :"
echo "    ~/planb-tools/scripts/migrations/2026-05-09_tasks_a_traiter.sql"
echo "  Cliquer Run."
