#!/usr/bin/env bash
# Versionne la migration SQL Phase 1 (fusion predefined_tasks ↔ fiches).
# La migration elle-même doit être appliquée manuellement dans Supabase Studio.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add scripts/migrations/2026-05-14_fiches_techniques_champs_taf.sql
git commit -m "chore: migration phase 1 — fiches_techniques + champs TAF

Première étape de la fusion predefined_tasks ↔ fiches_techniques
(décision Eric 14/5/2026 : fiches = source unique pour les tâches
de production).

scripts/migrations/2026-05-14_fiches_techniques_champs_taf.sql :
- Ajout de 5 colonnes à fiches_techniques :
    equipe (TEXT, default 'cuisine')
    creneau (TEXT, default 'Matin')
    categorie_taf (TEXT) — la catégorie TAF (Cuissons, Pâtisserie, etc.)
    produit (TEXT)
    action (TEXT)
- Backfill depuis predefined_tasks qui pointent vers chaque fiche
  (COALESCE pour ne pas écraser les valeurs par défaut).
- 2 index partiels pour requêtes futures (equipe, categorie_taf)
  WHERE actif = true.

Phase additive uniquement : rien n'est supprimé, le code existant
continue à fonctionner. La phase 2 (code front qui lit ces colonnes
depuis fiches) et la phase 3 (soft delete des predef de production)
suivront."

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer la migration dans Supabase Studio :"
echo "  Ouvre Supabase Studio (project dzrherfavgiuygnimtux), SQL Editor."
echo "  Copie-colle le contenu de :"
echo "    ~/planb-tools/scripts/migrations/2026-05-14_fiches_techniques_champs_taf.sql"
echo "  Clique Run."
echo
echo "  Puis lance les requêtes de validation (commentées en fin de fichier)"
echo "  pour vérifier que les colonnes sont créées et le backfill bon."
